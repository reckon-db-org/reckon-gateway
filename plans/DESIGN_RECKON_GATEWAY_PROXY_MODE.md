# DESIGN: reckon-gateway proxy mode

**Status:** draft (no code yet)
**Author:** session 2026-05-19
**Audience:** Raf

## Problem

Today reckon-gateway plays two roles in one process:

1. **Data plane** — it joins a clustered reckon-db via multicast gossip
   (`RECKON_DB_STORE_MODE=cluster`), holds local stores, owns workers.
2. **Ingress** — it terminates gRPC from clients (lazyreckon, the
   reckon-go SDK) and resolves each request to a local-or-cluster
   worker via `pg`.

That bundle is fine when the data-holder and the gRPC frontend are the
same Erlang node. It breaks down the moment we want one of the
following:

- Multiple disjoint reckon-db clusters owned by different services
  (e.g. `parksim_entry2exit_store` lives only inside the
  `parksim_entry2exit@beam00.lab` BEAM, not in the shared
  reckon-gateway cluster), but a single visualisation tool
  (lazyreckon) that can attach to any of them.
- A pure ingress tier that is stateless and can be horizontally scaled
  / restarted without touching data.

Concrete motivating case: the four `hecate-parksim-*` releases on
`beam00..03` each carry their own embedded reckon-db with stores like
`parksim_entry2exit_store`. They are in the same Erlang dist cluster
as the existing reckon-gateways (shared `RELEASE_COOKIE`), but they
are **not** in the same reckon-db cluster (different multicast group
+ secret, different membership). Lazyreckon cannot see them.

## Goal

Split reckon-gateway into two operational modes selected at boot via
env var:

| Mode | Data plane | Erlang dist | Routing | Today |
|------|------------|-------------|---------|-------|
| `embedded` (default) | reckon-db cluster member | yes | local `pg` workers (existing) | what the lab runs |
| `proxy` (new) | none — no reckon-db member | yes | dist rpc to whichever BEAM owns the store | the new mode |

A **proxy-mode** gateway is a pure gRPC ingress that translates
incoming RPCs into Erlang dist rpc calls against the BEAM that owns
the requested store. The gateway carries no reckon-db state.

Lazyreckon does not change semantically: it still says
`lazyreckon --endpoint host:port`. The optional `--cluster <label>`
flag is purely a local bookmark (like `Host` in `~/.ssh/config`); the
gateway never sees that label.

## Non-goals

- Multi-cluster routing inside one gateway. One proxy-mode gateway
  serves one Erlang dist cluster. To attach to two disjoint clusters
  you run two gateway instances; lazyreckon distinguishes them by
  endpoint + (client-side) label.
- Cross-cluster authorisation. Cookie scoping is the only gate, same
  as today.
- Protocol changes. The `reckon-proto` schemas, the
  `reckon_gater_api` callable surface, and the lazyreckon side stay
  intact except for one optional client-side flag.

## Today's wiring (annotated)

From the survey:

- `reckon_gateway_app.erl:11` boots `reckon_gateway_sup`.
- `reckon_gateway_sup.erl:14-51` registers nine gRPC services, each
  bound to a handler module (e.g. `StreamService →
  reckon_gateway_stream_service`). The supervisor starts only the
  gRPC server; reckon-db cluster join is implicit through
  `sys.config` and reckon-db's own multicast discovery
  (`RECKON_DB_STORE_MODE`, `RECKON_DB_CLUSTER_MULTICAST_ADDR`,
  `RECKON_DB_CLUSTER_SECRET`).
- Every gRPC handler shares the same shape:

  ```erlang
  Foo(#{store_id := StoreIdBin, ...} = Req, _Stream) ->
      {ok, StoreId} = reckon_gateway_convert:try_store_id(StoreIdBin),
      reckon_gater_api:some_op(StoreId, Args)
  ```

  So every data-plane call routes through `reckon_gater_api`, which
  internally does `route_call → select_worker → pick_worker` over
  `pg` groups keyed by `{reckon_db_store, StoreId}`. `pick_worker`
  prefers the local node and falls back to cluster-wide round-robin.

- `reckon_gateway_stores_service` is the discovery surface. Its
  `ListStores/GetStore/WatchStores` calls go through
  `reckon_db_store_registry`, which is a local registry replicated
  by reckon-db's own cluster mechanism.

The single seam used by every data RPC is therefore
`reckon_gater_api:route_call(StoreId, Request)`.

## Proxy-mode routing model

A proxy-mode gateway does **NOT** start reckon-db at all. It only:

1. Joins the Erlang dist cluster (cookie from env).
2. Hosts the gRPC server (unchanged).
3. On each incoming gRPC request, asks: "which Erlang node owns the
   store `StoreId`?" and forwards via `rpc:call/4`.

The answer to that question can be either looked up dynamically or
encoded by convention. The simple-and-correct first version is the
convention:

> Store name `<service>_store` is owned by node `<service>@<host>`
> within the cluster.

So `parksim_entry2exit_store` resolves to `parksim_entry2exit@<any
node-host in the cluster>`. The host part comes from looking through
the current dist `nodes()` for a node whose `name@` prefix matches.

Pseudocode:

```erlang
owner_for_store(StoreId) ->
    Prefix = drop_suffix(<<"_store">>, StoreId),  %% parksim_entry2exit
    case [N || N <- nodes(),
               lists:prefix(binary_to_list(Prefix), atom_to_list(N))] of
        [Node | _] -> {ok, Node};
        []         -> {error, no_owner}
    end.
```

This is enough for the parksim case. A future iteration can:

- Replace the convention with a `global:register_name/2` advert from
  each owning BEAM at boot.
- Or use the existing `reckon_db_store_registry` running on the
  owner node (the gateway can ask it via dist rpc on the first
  request, then cache).

For `ListStores` / `WatchStores`, the proxy iterates `nodes()` and
calls `reckon_db_store_registry:list_stores/0` on each via rpc;
merges the results.

Cookie is shared across the dist cluster, so authorisation is purely
the BEAM dist handshake. Same posture as the embedded mode.

## Patch surface

Per the survey, five files, ~165-295 LOC.

### 1. `config/sys.config.src` (~10 LOC)

Add a new app env block:

```erlang
{reckon_gateway, [
    {mode, ${RECKON_GATEWAY_MODE}},     %% "embedded" (default) | "proxy"
    {proxy_cluster_cookie, ${RECKON_GATEWAY_COOKIE}}
]}
```

In embedded mode, reckon-db env vars (`RECKON_DB_STORE_MODE` etc.)
behave as today. In proxy mode, reckon-db is not started at all —
release rel-config drops it from the boot apps list when
`RECKON_GATEWAY_MODE=proxy`. (Easier: keep reckon-db in the boot
list but call `application:set_env(reckon_db, store_mode, none)`
before start so it loads but doesn't join. The exact mechanism
depends on what reckon-db tolerates — TBD.)

### 2. `src/reckon_gateway_proxy.erl` (~80-120 LOC, new)

A small module that handles:

```erlang
-export([
    enabled/0,                            %% reads {reckon_gateway, mode}
    route_data_call/2,                    %% (StoreId, Fn) -> result
    route_admin_call/2,                   %% same shape, admin RPCs
    list_stores_across_cluster/0,
    watch_stores_across_cluster/2
]).

route_data_call(StoreId, Fn) when is_function(Fn, 2) ->
    case owner_for_store(StoreId) of
        {ok, Node}      -> rpc:call(Node, reckon_gater_api, Fn, [StoreId, Args]);
        {error, Reason} -> {error, Reason}
    end.
```

`owner_for_store/1` uses the convention above. Failures bubble up to
the gRPC handler as a structured error mapped to a gRPC status.

### 3. `src/reckon_gateway_stream_service.erl` + 8 sibling handlers (~50 LOC across nine files, or ~20 LOC if factored into a single dispatch)

Each handler today reads:

```erlang
reckon_gater_api:append_events(StoreId, StreamId, ...)
```

becomes:

```erlang
case reckon_gateway_proxy:enabled() of
    true  -> reckon_gateway_proxy:route_data_call(StoreId, {append_events, ...});
    false -> reckon_gater_api:append_events(StoreId, ...)   %% existing path
end
```

DRY: a single `dispatch/3` helper in `reckon_gateway_proxy` collapses
all nine sites to one switch line each.

### 4. `src/reckon_gateway_stores_service.erl` (~20-30 LOC)

The stores service needs cluster-wide queries in proxy mode:

```erlang
list_stores(_Req, _) ->
    case reckon_gateway_proxy:enabled() of
        true  -> reckon_gateway_proxy:list_stores_across_cluster();
        false -> reckon_db_store_registry:list_stores()       %% local only
    end.
```

`WatchStores` is harder because it's streaming — proxy mode probably
runs an in-gateway aggregator that subscribes to each remote node's
registry via dist and re-emits. That can be a phase-2 increment;
phase-1 returns a one-shot snapshot to lazyreckon, which already
polls.

### 5. `src/reckon_gateway_sup.erl` (~10-15 LOC)

Adds the proxy module to the child list when mode = proxy:

```erlang
Children = base_children() ++
           [proxy_child() || reckon_gateway_proxy:enabled()].
```

`proxy_child()` boots a small gen_server holding the cluster
membership cache (so we don't redo `nodes()` filter on every RPC).

## Open questions

1. **reckon-db tolerates being loaded but not started?** The `mode`
   env var trick assumes reckon-db respects the absence of its
   discovery config. If not, we need a `prod-proxy` profile in
   rebar.config that drops reckon-db entirely. TBD by reading
   reckon-db's startup behaviour.

2. **Store-owner convention vs. registry**. Today's parksim release
   names happen to share a prefix with their store names
   (`parksim_entry2exit@... ↔ parksim_entry2exit_store`). For other
   services this could differ. Recommend: ship the convention now;
   add an optional `global:register_name({reckon_db_store, X}, Pid)`
   from each owner BEAM in a follow-up; proxy prefers `global` if
   present.

3. **WatchStores streaming under proxy**. Phase-1 returns a snapshot.
   Phase-2 needs a proper aggregator. Will lazyreckon notice the
   downgrade? Worth testing before commit.

4. **Single point of failure**. One proxy-mode gateway in front of
   N BEAMs has no HA today. Embedded-mode is no different (also one
   gateway per cluster), so this is parity. Adding redundancy is a
   separate workstream.

5. **Cookie management**. The proxy gateway must know the cookie of
   the BEAM cluster it serves. It comes from `RELEASE_COOKIE` (same
   path as today). No new secret distribution.

## Migration path

No flag-day. Existing reckon-gateway deployments stay in `embedded`
mode by default (env unset). To attach lazyreckon to parksim:

1. Build the next reckon-gateway image with the patches above.
2. Stand up a new gateway instance with
   `RECKON_GATEWAY_MODE=proxy`, `RELEASE_COOKIE` matching the
   parksim cluster cookie, and a distinct host/port. This instance
   is **not** part of the existing 5-node reckon-gateway cluster
   (different role; pure ingress).
3. Lazyreckon: `lazyreckon --endpoint <new-gateway-host>:50051`.
   Verify it sees `parksim_entry2exit_store` and friends.
4. Keep the embedded-mode reckon-gateway instances running
   alongside, untouched.

Rollback is just stopping the new instance. Nothing in the parksim
or embedded-mode side is affected.

## What this doc deliberately doesn't decide

- Whether to expose `cluster_name` over the wire. The user's note
  was emphatic: it stays client-side only. So nothing in this doc.
- Whether to also fix the `reckon_db_store_registry` so it
  replicates *across* reckon-db clusters via dist. That's a
  reckon-db change, not a gateway change. Out of scope.
- Whether to add HA / N+1 redundancy for proxy gateways. Phase 2.

## Next step (after this doc is approved)

Sub-task list, smallest first:

1. Verify reckon-db's behaviour when loaded but not joined to a
   cluster (read its discovery code, check whether it errors out at
   `application:start/1` or just sits idle).
2. Add the env var + supervisor branch behind a feature flag.
3. Add `reckon_gateway_proxy` module + the dispatch switch in one
   handler (e.g. ListStores) for end-to-end smoke.
4. Verify in lazyreckon against `parksim_entry2exit@beam00.lab`.
5. Roll out across all nine handlers.
6. Decide on WatchStores phase-2 aggregator vs. snapshot.
