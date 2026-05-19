# RESEARCH: catalogue-mode load-bearing spike results

**Status:** complete (verdict: NOT ready for implementation yet)
**Author:** session 2026-05-19
**Audience:** Raf
**Related:** [DESIGN_RECKON_GATEWAY_CATALOGUE.md](DESIGN_RECKON_GATEWAY_CATALOGUE.md)

Three short spikes ran against the lab before any catalogue
implementation work began. Scripts kept in `scripts/`:

- `scripts/verify-catalogue-assumptions.sh` — the three core spikes.
- `scripts/probe-parksim-store-state.sh` — follow-up after spike 3
  surfaced unexpected emptiness.
- `scripts/probe-existing-gateway.sh` — comparison probe against
  the live embedded-mode reckon-gateway.

## Verdict

| Spike | Assumption | Result |
|-------|------------|--------|
| 1 | `erlang:set_cookie(Node, Cookie)` enables per-peer dist auth from a BEAM whose default cookie is different | ✅ PASS — `pong` returned; default cookie untouched; only the target node connected |
| 2 | `rpc:call(Target, pg, which_groups, [Scope])` reaches the remote BEAM's pg state via dist rpc | ✅ PASS — 13 event-topic groups returned from `parksim_entry2exit`'s pg scope |
| 3 | `reckon_db_store_registry:list_stores/0` on a parksim BEAM returns the configured store_id | ❌ FAIL — registry returns `{ok, []}`; no parksim store is registered |

Spikes 1 + 2 confirm the catalogue's dist-routing mechanism is
sound. Spike 3 surfaces a real architectural gap that BLOCKS
catalogue implementation as designed.

## What spike 3 actually shows

`reckon_db_store_registry` IS running on parksim BEAMs (it's part
of reckon-db, which is in the parksim release). The registry is
queryable. It just contains no stores, because **parksim never
starts a `reckon_db_store` process**.

Evidence on `parksim_entry2exit@192.168.1.10`:

```
reckon_db_sup children:
  [{reckon_db_store_registry, <pid>, worker, ...},
   {reckon_db_pg_scope,       <pid>, worker, ...}]
```

Compare to the live embedded-mode reckon-gateway on the laptop:

```
reckon_db_sup children:
  [{reckon_db_system_default_store, <pid>, supervisor, ...},  %% <-- the actual store
   {reckon_db_store_registry,       <pid>, worker, ...},
   {reckon_db_pg_scope,             <pid>, worker, ...}]
```

The live gateway's registry holds one entry per cluster member:

```
[#{store_id => default_store, node => reckon_gateway@192.168.1.10, mode => cluster, ...},
 #{store_id => default_store, node => reckon_gateway@192.168.1.11, mode => cluster, ...},
 ...]
```

Parksim has the registry but no `reckon_db_system_*_store` child
sitting alongside it. The store_id `parksim_entry2exit_store` in
parksim's app env is **dangling** — set, but read by no module.

## Why this happened

evoq on parksim has its own `{store_id, default_store}` env entry
and `reckon_evoq`'s env is empty (`[]`). The intended chain was:

```
parksim app env (event_store_id)
   → evoq app env (store_id)
   → reckon_evoq adapter
   → reckon_db_store
   → reckon_db_store_registry
```

In the actual parksim release that chain is broken at the first
arrow: nothing copies `event_store_id` from parksim's env into
evoq's env or into reckon_evoq's config. evoq runs in its default
mode using an in-memory ETS-backed event log. Events sent through
evoq aggregates (the `evoq_aggregate_partition_sup_*` processes
are alive) land somewhere ephemeral. There is no persistent
reckon-db backing on parksim today.

## Implications

1. **Parksim's event sourcing is ephemeral.** Restart a parksim
   BEAM and its events are gone. The simulator drives traffic
   through `macula:call` (dry-run today, even when set to false
   per the .env, the mesh path is the only consumer) — but even
   if the entry2exit RPC path fires, the aggregate updates are
   stored in evoq's default ETS, not in reckon-db.

2. **lazyreckon cannot see anything from parksim,** regardless of
   how the catalogue gateway is built, because there is no
   persistent store to discover.

3. **The catalogue design is correct but its premise is unmet.**
   The spike confirms the dist-routing mechanism, the per-peer
   cookies, the rpc:call surface. The gateway can be built. It
   just won't have anything to show.

## What needs to change in parksim before catalogue implementation

Pick one of three paths. The cheapest is path A.

### Path A — Wire evoq through reckon_evoq → reckon_db (recommended)

For each parksim CMD app (entry2exit, lot, pricing):

1. In `config/sys.config.src`, add the reckon-db config block so a
   `reckon_db_system_*_store` actually starts at boot. Mirror the
   shape used by the existing reckon-gateway:

   ```erlang
   {reckon_db, [
       {store_mode, single},
       {data_dir,   "${HECATE_DATA_DIR}"},
       {stores,     [parksim_entry2exit_store]}
   ]},
   {evoq, [
       {store_id, parksim_entry2exit_store},
       {aggregate_partitions, 4}
   ]},
   {reckon_evoq, [
       {store_id, parksim_entry2exit_store}
   ]}
   ```

2. Verify on rebuild: `reckon_db_sup` has a
   `reckon_db_system_parksim_entry2exit_store_sup` child;
   `reckon_db_store_registry:list_stores/0` returns the entry.

3. Drive a write through evoq and confirm it lands in the store.

LOC estimate: ~15 LOC per CMD app × 3 apps = ~45 LOC of config.
No code changes if the wiring already works via env. If it
doesn't, modest application-level glue (~50 LOC) to ensure the
store starts on boot.

### Path B — Drop reckon-db from parksim, use evoq's in-memory only

Accept that parksim events are ephemeral. Don't try to make
lazyreckon show them. The catalogue gateway is still useful for
any FUTURE reckon-db-using cluster, but parksim is out of scope.

LOC estimate: ~10 LOC (remove dangling env entries from parksim
sys.config). Honest, but defeats the original goal.

### Path C — Build a different discovery surface

The catalogue queries something other than `reckon_db_store_registry`.
For evoq-backed services that don't use reckon-db, query
`evoq_aggregate_registry` (it's a registered process; needs to
expose a `list_aggregates/0` or similar). This means the
catalogue knows two backends and switches based on what each
cluster exposes.

LOC estimate: +100-200 LOC in the catalogue; doesn't fix parksim
itself.

## Recommendation

**Path A.** It's the smallest change, restores the original
event-sourcing claim in the parksim architecture, and lets the
catalogue work as designed. Do it BEFORE writing any catalogue
code.

Sub-task list, BLOCKING the catalogue implementation:

1. Add the reckon-db / evoq / reckon_evoq config blocks to each
   parksim CMD app's `sys.config.src`. Rebuild image, redeploy
   one beam, re-run `verify-catalogue-assumptions.sh`. Spike 3
   should now return a non-empty list.
2. Drive a write through evoq (HTTP API + a dispatch) and
   confirm it appears in the store via
   `reckon_db_store_registry:get_store_info/1`.
3. Update parksim's design or comments to acknowledge the wiring.

After that, the catalogue implementation in
`DESIGN_RECKON_GATEWAY_CATALOGUE.md` is fully unblocked.

## What this doc does NOT recommend

- Don't drop the catalogue design. The spike validated its
  mechanism (spikes 1 + 2). The discovery surface is fine; the
  ABSENCE of a thing to discover is the issue.
- Don't start coding the catalogue while parksim is still
  ephemeral. That's a waste — the catalogue would ship with no
  way to demonstrate value.
- Don't bypass the wiring with hacks (e.g. hardcoding store_ids
  into clusters.eterm). That re-introduces the operator-pinned
  catalogue we already rejected.
