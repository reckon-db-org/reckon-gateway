# RESEARCH: catalogue-mode load-bearing spike results

**Status:** complete (verdict: BLOCKED until parksim is wired per the canonical pattern)
**Author:** session 2026-05-19
**Audience:** Raf
**Related:** [DESIGN_RECKON_GATEWAY_CATALOGUE.md](DESIGN_RECKON_GATEWAY_CATALOGUE.md)

Three pre-implementation spikes ran against the lab. Scripts in
`scripts/`:

- `verify-catalogue-assumptions.sh` — the three core spikes.
- `probe-parksim-store-state.sh` — follow-up after spike 3 surfaced
  unexpected emptiness.
- `probe-existing-gateway.sh` — comparison probe against the live
  embedded-mode reckon-gateway (which DOES have a store).
- `probe-evoq-surfaces.sh` — diagnostic on the evoq side of the
  parksim BEAM.

## Verdict

| Spike | Assumption | Result |
|-------|------------|--------|
| 1 | `erlang:set_cookie(Node, Cookie)` enables per-peer dist auth from a BEAM whose default cookie differs | ✅ PASS — `pong`; default cookie untouched; only target appeared in `nodes()` |
| 2 | `rpc:call(Target, pg, which_groups, [Scope])` reaches remote BEAM's pg via dist | ✅ PASS — 13 event-topic groups returned |
| 3 | `reckon_db_store_registry:list_stores/0` on parksim BEAM returns the configured store_id | ❌ FAIL — registry returns `{ok, []}`; no `reckon_db_system_*_store` child present |

Spikes 1 + 2 confirm the catalogue's dist-routing mechanism. Spike 3
surfaces a real wiring gap in the parksim CMD apps that blocks
catalogue implementation as designed.

## What spike 3 actually shows

`reckon_db_store_registry` IS running on parksim BEAMs — but
`reckon_db_sup` only has the registry + a pg-scope as children. No
`reckon_db_system_*_store` is ever booted.

```
%% parksim_entry2exit BEAM
reckon_db_sup children:
  [{reckon_db_store_registry, <pid>, worker, ...},
   {reckon_db_pg_scope,       <pid>, worker, ...}]
```

vs. the live embedded-mode reckon-gateway:

```
%% reckon_gateway BEAM (laptop)
reckon_db_sup children:
  [{reckon_db_system_default_store, <pid>, supervisor, ...},  %% the actual store
   {reckon_db_store_registry,       <pid>, worker, ...},
   {reckon_db_pg_scope,             <pid>, worker, ...}]
```

`reckon_db_store_registry:list_stores/0` on the gateway returns one
entry per cluster member; on parksim it returns nothing because
nothing has been registered.

## Root cause — parksim skips the canonical CMD/PRJ wiring

The canonical wiring for a CMD/PRJ service is documented in two
places I should have consulted at the start of this design session:

### 1. `hecate-social/hecate-corpus/skills/ANTIPATTERNS_EVENT_SOURCING.md`

Explicit, mandatory pattern (quoted):

```erlang
%% sys.config / config.exs
{evoq, [
    {event_store_adapter, reckon_evoq_adapter},
    {subscription_adapter, reckon_evoq_adapter}
]}.

%% Store Creation (MANDATORY at app startup)
Config = #store_config{
    store_id = my_domain_store,
    data_dir = "/path/to/store",
    mode = single
},
{ok, _Pid} = reckon_db_sup:start_store(Config).
```

> "Without both of these, evoq will crash on first dispatch."

### 2. `hecate-social/hecate-daemon/config/sys.config`

The working reference. Comments inside it spell out the contract:

```erlang
%% ReckonDB Configuration (Embedded Event Store)
%% NOTE: Stores are NOT configured here. Each domain starts its own
%% store via reckon_db_sup:start_store/1 in its supervisor's init/1.
%% This follows VERTICAL SLICING - domains own their infrastructure.
{reckon_db, [
    %% Global defaults (used if domain doesn't specify)
    {writer_pool_size, 5},
    {reader_pool_size, 5},
    {gateway_pool_size, 1}
    %% NO {stores, [...]} here! Domains start their own stores.
]},

%% Evoq Configuration (CQRS Framework)
%% NOTE: evoq looks for 'event_store_adapter', NOT 'default_adapter'!
{evoq, [
    {event_store_adapter, reckon_evoq_adapter},
    {subscription_adapter, reckon_evoq_adapter},
    {store_id, default_store},
    {consistency, eventual}
]}
```

### What parksim's sys.config has instead

```erlang
[
    {hecate_parksim_entry2exit, [
        {http_port,       8470},
        {data_dir,        "${HECATE_DATA_DIR}"},
        {event_store_id,  parksim_entry2exit_store},   %% <-- dangling, read by nothing
        {max_dwell_days,  30}
    ]},
    {hecate_om, [...]},
    {kernel, [...]}
].
```

No `{evoq, [{event_store_adapter, ...}]}` block. No `reckon_db_sup:start_store/1`
call anywhere in parksim's app start path. `event_store_id` sits in
the parksim_X app env but no module reads it. evoq defaults to
in-memory `default_store`.

This is the entire bug.

## The fix — apply the canonical pattern to each parksim CMD app

Per `ANTIPATTERNS_EVENT_SOURCING.md`. Two changes per parksim CMD
app (entry2exit, lot, pricing — the simulator is a producer-only
client and doesn't need a store).

### Change 1 — sys.config.src (each parksim CMD app)

Append the canonical evoq + reckon_db block:

```erlang
{reckon_db, [
    {writer_pool_size, 5},
    {reader_pool_size, 5},
    {gateway_pool_size, 1}
]},

{evoq, [
    {event_store_adapter, reckon_evoq_adapter},
    {subscription_adapter, reckon_evoq_adapter},
    {store_id, parksim_entry2exit_store},
    {consistency, eventual}
]},
```

### Change 2 — start the store + subscription at app boot

In each `hecate_parksim_X_app:start/2`, prepend a store-start
before `hecate_om:boot/1`:

```erlang
-include_lib("reckon_db/include/reckon_db.hrl").

start(_StartType, _StartArgs) ->
    {ok, DataDir} = application:get_env(hecate_parksim_entry2exit, data_dir),
    {ok, StoreId} = application:get_env(hecate_parksim_entry2exit, event_store_id),

    %% Canonical pattern per ANTIPATTERNS_EVENT_SOURCING.md:
    %% domain starts its own reckon-db store, then the per-store
    %% evoq subscription, then the rest of the service.
    Config = #store_config{
        store_id          = StoreId,
        data_dir          = filename:join(DataDir, atom_to_list(StoreId)),
        mode              = single,
        writer_pool_size  = 5,
        reader_pool_size  = 5,
        gateway_pool_size = 1,
        options           = #{}
    },
    {ok, _} = reckon_db_sup:start_store(Config),
    ok = wait_for_store(StoreId, 30000),
    {ok, _} = evoq_store_subscription:start_link(StoreId),

    hecate_om:boot(hecate_parksim_entry2exit_service).

wait_for_store(StoreId, TimeoutMs) ->
    Deadline = erlang:monotonic_time(millisecond) + TimeoutMs,
    wait_for_store_loop(StoreId, Deadline).

wait_for_store_loop(StoreId, Deadline) ->
    case lists:member(StoreId, reckon_db_sup:which_stores()) of
        true  -> ok;
        false ->
            case erlang:monotonic_time(millisecond) > Deadline of
                true  -> {error, {store_not_ready, StoreId}};
                false -> timer:sleep(100), wait_for_store_loop(StoreId, Deadline)
            end
    end.
```

Same shape for `hecate_parksim_lot_app` and
`hecate_parksim_pricing_app` (different store_id).

### Verification

After the fix, redeploy one parksim and re-run
`scripts/verify-catalogue-assumptions.sh`. Spike 3 should now
return:

```
reckon_db_store_registry:list_stores() = {ok, [
    #{store_id => parksim_entry2exit_store,
      node     => 'parksim_entry2exit@192.168.1.10',
      mode     => single, ...}
]}
```

At that point the catalogue gateway implementation is fully
unblocked.

## What I got wrong in the earlier draft of this doc

The previous draft of this RESEARCH doc proposed adding a
`{stores, [...]}` block to parksim's sys.config. **That's the
wrong shape.** hecate-daemon's sys.config has an explicit comment
saying "NO `{stores, [...]}` here! Domains start their own
stores." The canonical pattern is **store_start in the app's
start/2 (or its first supervisor's init/1)**, not in sys.config.

I should have consulted `hecate-corpus/skills/ANTIPATTERNS_EVENT_SOURCING.md`
and `hecate-daemon/config/sys.config` before writing the
recommendation. The session-init hook even loaded the
hecate-corpus files; I ignored them and reasoned in a vacuum. The
output of that vacuum was a fix that violated the codebase's
established convention.

This doc is rewritten to match the canonical pattern. Future
parksim-style services should follow `ANTIPATTERNS_EVENT_SOURCING.md`
and the hecate-daemon reference, not this RESEARCH doc.

## LOC estimate (corrected)

Per parksim CMD app:

- `config/sys.config.src`: +12 lines (the reckon_db + evoq blocks)
- `src/hecate_parksim_X_app.erl`: +25 lines (store-start + wait helper)
- `rebar.config`: 0 lines (reckon_db is already a dep)

Three CMD apps × ~37 LOC = **~110 LOC total**. Simulator unchanged
(producer-only).

## Status

`DESIGN_RECKON_GATEWAY_CATALOGUE.md` marked BLOCKED until this
parksim wiring lands. After the fix:

1. Verify with `scripts/verify-catalogue-assumptions.sh`.
2. Confirm spike 3 returns a non-empty store list.
3. Drive one event through evoq, check it lands in the store via
   `reckon_db_store_registry:get_store_info/1`.
4. Unblock the catalogue design; resume the original
   implementation sub-task list.

## Bigger lesson

The session-init hook lists philosophy + skills files for a reason.
When designing or diagnosing, **consult them first** — they
encode hard-won decisions. Re-deriving from probe output alone
produces plausible-looking advice that contradicts the codebase
convention.
