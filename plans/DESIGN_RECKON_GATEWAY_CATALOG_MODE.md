# DESIGN: reckon-gateway catalog mode

**Status:** draft (no code yet)
**Author:** session 2026-05-19
**Audience:** Raf
**Supersedes:** [DESIGN_RECKON_GATEWAY_PROXY_MODE.md](DESIGN_RECKON_GATEWAY_PROXY_MODE.md)

## Problem

Today reckon-gateway plays two roles in one process:

1. **Data plane** — it joins a clustered reckon-db via multicast gossip
   (`RECKON_DB_STORE_MODE=cluster`) and holds local stores.
2. **Ingress** — it terminates gRPC from clients (lazyreckon, the
   reckon-go SDK) and resolves each request to a local-or-cluster
   worker via `pg`.

That bundle works when the data-holder and the gRPC frontend are the
same Erlang cluster. It breaks down the moment we want a single
operator-facing endpoint that exposes data from **multiple disjoint
reckon-db clusters**, each owned by a different Erlang dist cluster
(distinct cookies).

Concrete motivating case: the four `hecate-parksim-*` releases on
`beam00..03` carry their own embedded reckon-db with stores like
`parksim_entry2exit_store`. The existing reckon-gateway cluster on the
same beams carries its own stores. A future `hecate-marketplace`
service will carry yet another set. Each is a separate cookie-scoped
Erlang dist cluster. lazyreckon today cannot see any of them via one
gateway.

## Goal

Add a **catalog mode** to reckon-gateway that:

- Connects to N disjoint Erlang dist clusters concurrently using
  per-peer cookies (Erlang's `set_cookie(Node, Cookie)` semantics).
- Maintains a unified catalog of every store across every connected
  cluster: `{store_name → cluster_id}`. `cluster_id` is an
  operator-assigned opaque label (e.g. `"parksim"`, `"marketplace"`).
- Exposes one gRPC endpoint that lists the catalog, then routes each
  data RPC to the right cluster member via Erlang dist `rpc:call`.
- Never returns cookies to clients. Cookies live in the gateway's
  config + memory only.
- Hot-reloadable: add/remove clusters at runtime without restarting
  the gateway container.

### Lazyreckon UX (the target)

```
$ lazyreckon --endpoint gateway.lab:50051
┌─ ◉ lazyreckon · gateway.lab:50051 · ● 3 clusters / 17 stores ────┐
│                                                                  │
│  cluster              │  stores                  │  events       │
│  ▸ parksim            │  parksim_entry2exit      │  v0 …         │
│    marketplace        │  parksim_lot             │               │
│    default            │  parksim_pricing         │               │
│                       │  parksim_simulator       │               │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

One endpoint, three clusters visible, all their stores browsable. No
client-side cookies, no per-cluster bookmark management.

## Non-goals

- **No protocol-level cluster naming.** `cluster_id` is operator-side
  metadata returned by `ListStores`; it doesn't carry cookies and the
  on-wire schema only treats it as an opaque routing tag.
- **No authn / authz at the gRPC layer.** Same posture as today
  (LAN-trust). Multi-cluster visibility increases the blast radius if
  the gateway port is reachable beyond intended operators; flagged in
  Open Questions but not solved here.
- **No HA / N+1 redundancy** for the gateway itself. Two catalog-mode
  gateways with the same config form an obvious A/A pair (each
  connects independently to all clusters) but the lazyreckon client
  picks one endpoint; failover is the client's problem.
- **No store-name disambiguation** across clusters. Operator
  guarantees globally-unique store names in their catalog config;
  gateway errors at config load on duplicates.

## Today's wiring (annotated)

From the previous survey:

- `reckon_gateway_app.erl:11` boots `reckon_gateway_sup`.
- `reckon_gateway_sup.erl:14-51` registers nine gRPC services, each
  bound to a handler module. The supervisor starts only the gRPC
  server; reckon-db cluster join is implicit through `sys.config` and
  reckon-db's own multicast discovery.
- Every gRPC handler shares the same shape:

  ```erlang
  Foo(#{store_id := StoreIdBin, ...} = Req, _Stream) ->
      {ok, StoreId} = reckon_gateway_convert:try_store_id(StoreIdBin),
      reckon_gater_api:some_op(StoreId, Args)
  ```

  Every data-plane call routes through `reckon_gater_api`, which
  internally does `route_call → select_worker → pick_worker` over `pg`
  groups keyed by `{reckon_db_store, StoreId}`. `pick_worker` prefers
  the local node and falls back to cluster-wide round-robin.

- `reckon_gateway_stores_service` is the discovery surface. Its
  `ListStores/GetStore/WatchStores` calls go through
  `reckon_db_store_registry`, a local registry replicated by
  reckon-db's own cluster mechanism.

The single seam used by every data RPC is therefore
`reckon_gater_api:route_call(StoreId, Request)`. The single seam for
discovery is `reckon_db_store_registry`. Catalog mode replaces both.

## Catalog-mode design

### Operating model

The gateway runs in one of two modes selected at boot:

| Mode | Data plane | Erlang dist | Discovery | Today |
|------|------------|-------------|-----------|-------|
| `embedded` (default) | reckon-db cluster member | one cluster, default cookie | local `reckon_db_store_registry` | what the lab runs |
| `catalog` (new) | none — not a reckon-db member | N clusters via per-peer cookies | merged catalog from each cluster's registry | the new mode |

In catalog mode the gateway:
- Does NOT join reckon-db as a cluster member.
- DOES join N Erlang dist clusters concurrently (per-peer cookie
  setting); each cluster's gossip is cookie-scoped, so the clusters
  don't see each other through the gateway.
- Sets `dist_auto_connect = never` so auto-connect attempts to
  newly-gossiped nodes don't fire with wrong cookies. All connections
  are explicit.

### Per-cluster connector

One gen_server per configured cluster. Lifecycle:

```
init(#{id := Id, seed := Seed, cookie := Cookie}) ->
    erlang:set_cookie(Seed, Cookie),
    case net_adm:ping(Seed) of
        pong  ->
            Members = rpc:call(Seed, erlang, nodes, []),
            [begin
                erlang:set_cookie(M, Cookie),
                net_kernel:connect_node(M)
             end || M <- [Seed | Members]],
            schedule_refresh(),
            {ok, #state{id = Id, seed = Seed, cookie = Cookie,
                        members = [Seed | Members],
                        stores = discover_stores([Seed | Members]),
                        status = up}};
        pang ->
            schedule_retry(),
            {ok, #state{id = Id, seed = Seed, cookie = Cookie,
                        members = [], stores = [], status = unreachable}}
    end.
```

Periodic refresh (configurable, default 30s):
- Re-query `rpc:call(Member, erlang, nodes, [])` to learn membership
  changes.
- Re-query `rpc:call(Member, reckon_db_store_registry, list_stores, [])`
  to learn store changes.
- Pick the first healthy member each time; failover to other members
  on `badrpc`.

Node-down handling (`monitor_node/2` on each member):
- Drop the dead member from the local list.
- If all members are dead, mark cluster `unreachable`, keep retrying
  the seed in the background.

### Catalog aggregator

A single gen_server holding the union view:

```
#state{
    catalog = #{StoreName => ClusterId, ...},
    clusters = #{ClusterId => #cluster_info{...}, ...}
}.
```

API:

```erlang
lookup(StoreName) -> {ok, ClusterId, Members} | {error, not_found | unreachable}.
list_all() -> [{StoreName, ClusterId, Status}, ...].
ensure_unique(NewStores, ClusterId) -> ok | {error, {duplicate, StoreName, OtherClusterId}}.
```

Connectors call `ensure_unique` before publishing their store list.
Duplicate detection => log + reject the cluster's stores until
operator resolves it (gateway stays up; the offending cluster's
stores stay invisible).

### gRPC layer changes

**Discovery RPCs** (`StoresService`):

- `ListStores()` returns the flat union: `[{store_id, cluster_id, status}, ...]`.
- `GetStore(store_id)` returns the matching entry.
- `WatchStores()` (streaming): the gateway aggregates per-cluster
  registry watches into one stream. Phase-1 can emit periodic
  snapshots instead of true incremental updates if the streaming
  implementation is heavy.

**Data RPCs** (the eight other services):

The handler shape changes from:

```erlang
Foo(#{store_id := StoreIdBin, ...}, _) ->
    {ok, StoreId} = reckon_gateway_convert:try_store_id(StoreIdBin),
    reckon_gater_api:some_op(StoreId, Args).
```

to:

```erlang
Foo(#{store_id := StoreIdBin, ...}, _) ->
    {ok, StoreId} = reckon_gateway_convert:try_store_id(StoreIdBin),
    case reckon_gateway_catalog:lookup(StoreId) of
        {ok, _ClusterId, Members} ->
            Member = pick_member(Members),
            rpc:call(Member, reckon_gater_api, some_op, [StoreId, Args]);
        {error, not_found} ->
            {error, store_unknown};
        {error, unreachable} ->
            {error, cluster_unavailable}
    end.
```

`pick_member/1` is a small round-robin / health-aware selector over
the cluster's known members.

DRY: the eight data-plane handlers collapse into one shared dispatch
helper, mode-aware: in embedded mode call the existing
`reckon_gater_api:route_call`, in catalog mode call the dispatch
above. Single switch line per handler.

### Admin RPCs

`AdminService` gets two new methods:

- `ReloadCatalog()` — re-reads the clusters config file, diffs against
  the live state, spawns/retires connectors as needed. No gateway
  restart.
- `GetCatalogStatus()` — returns per-cluster status: `{cluster_id,
  seed, members, store_count, status, last_refresh}`. Used by ops
  tooling.

## The cookie-exposure rule

> **Cookies never cross the gateway → client boundary.**

Cookies are Erlang's auth credential. Anyone who learns one can join
the cluster as a peer and read or mutate anything. The gateway holds
cookies in config + memory and uses them on the dist side; on the
gRPC side they are NEVER returned, even in error messages.

`cluster_id` is the only routing tag clients see. It's an
operator-assigned label, not the cookie. Even if the entire catalog
leaks, the worst outcome is a list of cluster labels and store names,
not credentials.

## Config shape

In `config/sys.config.src` (env-driven shape):

```erlang
{reckon_gateway, [
    {mode, ${RECKON_GATEWAY_MODE}},              %% "embedded" | "catalog"
    {clusters_config_path, "${RECKON_GATEWAY_CLUSTERS_PATH}"}
]}
```

`clusters_config_path` points at a separate file (NOT in gitops, in
`~/.hecate/secrets/reckon-gateway-clusters.eterm` or similar) holding
the actual cluster list with cookies:

```erlang
%% Erlang term file. Reloadable via AdminService.ReloadCatalog.
[
    #{id => parksim,
      seed => 'parksim_entry2exit@192.168.1.10',
      cookie => <<"tKcKQnLjuoAVECwP9TcfA2AQJvA6QzL4ZcnykOihzQw">>,
      refresh_interval_ms => 30000},

    #{id => marketplace,
      seed => 'marketplace_main@192.168.1.50',
      cookie => <<"abcd...">>,
      refresh_interval_ms => 60000}
].
```

The split (sys.config has the path; the secrets file has the actual
secrets) is so the cookies stay out of any image, gitops repo, or
container logs.

## Patch surface

Roughly **300-450 LOC** across new modules + targeted edits:

| Module | LOC | Role |
|---|---|---|
| `src/reckon_gateway_cluster_connector.erl` (new) | 120-180 | One gen_server per cluster. Holds members + stores; refresh timer; node monitor. |
| `src/reckon_gateway_catalog.erl` (new) | 60-100 | Aggregator. Catalog map. lookup / list_all / ensure_unique. |
| `src/reckon_gateway_clusters_sup.erl` (new) | 30-50 | dynamic_supervisor over connectors. Loaded from config; restarted via ReloadCatalog. |
| `src/reckon_gateway_dispatch.erl` (new) | 40-60 | Mode-aware helper called from each gRPC handler. |
| `src/reckon_gateway_admin_service.erl` (modify) | +50 | ReloadCatalog, GetCatalogStatus RPCs. |
| `src/reckon_gateway_stores_service.erl` (modify) | +30 | ListStores/GetStore/WatchStores use catalog in mode=catalog. |
| 8 other gRPC service handlers (modify) | +5 each = 40 | Mode-aware switch via reckon_gateway_dispatch. |
| `src/reckon_gateway_sup.erl` (modify) | +10-15 | Boot clusters_sup if mode=catalog. |
| `config/sys.config.src` (modify) | +10 | Mode + clusters_config_path. |
| `gen/reckon_admin.proto` (modify) | +20 | ReloadCatalog + GetCatalogStatus message types. |

## Operational model

| Concern | How it's handled |
|---|---|
| Add a cluster | Edit `clusters.eterm`, `AdminService.ReloadCatalog`. No restart. |
| Remove a cluster | Same, in reverse. Connector terminates, catalog drops its stores. |
| Cluster goes offline | Connector marks it unreachable; catalog reports `status = unreachable`; RPCs against those stores return `cluster_unavailable`. |
| Cluster comes back | Connector retries the seed; on success, repopulates members + stores; status flips to `up`. |
| New store in a live cluster | Connector's periodic refresh picks it up (<30s lag). |
| Store removed | Same path. |
| Cluster member moves (e.g. `parksim_lot@beam01` → `parksim_lot@beam04`) | Refresh re-queries `nodes()`. Old member gets pruned, new one connected. Cookie unchanged. |
| Cookie rotation on a cluster | Operator updates `clusters.eterm`, ReloadCatalog. Connector reconnects with new cookie. Brief unavailability window. |
| Duplicate store name across clusters | Config-load error logged; offending cluster's stores stay invisible. Operator's responsibility to fix. |

## Open questions

1. **Can reckon-db be loaded but not started?** Catalog mode wants
   reckon-db's beam/code present (for type definitions, helpers) but
   wants the discovery + cluster-join machinery NOT to run. Either:
   - Drop reckon-db from the boot apps list in a new
     `prod-catalog` rebar profile, OR
   - `application:set_env(reckon_db, store_mode, none)` before start
     and trust reckon-db to be a no-op.

   First option is safer; second is simpler. Decide after reading
   reckon-db's startup code.

2. **`dist_auto_connect = never` interaction with monitor_node.**
   `monitor_node/2` works on connected nodes regardless of
   auto-connect. Should be fine, but worth a smoke test.

3. **WatchStores streaming aggregation** is non-trivial. Phase-1:
   periodic snapshot pushed on the stream. Phase-2: subscribe to
   each cluster's `reckon_db_store_registry` events via dist and
   merge into one stream. Likely doable later; lazyreckon already
   polls for safety.

4. **Refresh interval tuning.** 30s default may be too long for
   "new store just published" responsiveness or too short for a
   busy gateway. Per-cluster setting; document trade-offs.

5. **rpc:call timeout policy.** Today `reckon_gater_api` calls
   are local-cheap. With dist rpc they cross a network. Default
   `rpc:call` timeout is 5s; for streaming reads we may need
   `rpc:call(..., infinity)` with explicit cancellation. Phase-1:
   5s default, document the limitation.

6. **Auth on the gRPC layer.** Single-cluster gateway today has
   none. Catalog mode multiplies the blast radius. Out of scope
   for this design, but flagged for whoever exposes the gateway
   outside a trusted LAN.

7. **Lazyreckon UX changes.** Adding a `cluster` column / grouper
   to the stores mode is a non-trivial UI change. Either ship the
   gateway change first and let the existing lazyreckon render the
   flat list (cluster_id as a column, no grouping), or coordinate
   the lazyreckon update.

## Migration path

No flag-day:

1. Build the next reckon-gateway image with the catalog mode patches.
2. Existing reckon-gateway deployments stay in `embedded` mode by
   default (env unset). Nothing changes for them.
3. Stand up a new gateway instance with `RECKON_GATEWAY_MODE=catalog`
   and a `clusters.eterm` listing the parksim cluster (and any
   others). The new instance is a separate systemd unit /
   container; it lives alongside the embedded-mode ones.
4. Lazyreckon: `lazyreckon --endpoint <new-gateway-host>:50051`. The
   stores list now shows everything in the catalog.
5. Rollback = stop the new container. Nothing else affected.

## What this doc deliberately doesn't decide

- **`cluster_name` on the wire.** Per prior conversation, the client-
  side label stays client-side. The gateway returns `cluster_id` only
  because lazyreckon needs to group/disambiguate. The two are not
  the same: `cluster_id` is gateway-assigned in `clusters.eterm`;
  `cluster_name` (if ever added) would be a client bookmark for the
  gateway endpoint itself, not for a cluster within a gateway.

- **HA for the gateway.** Phase 2.

- **Cross-cluster transactions or queries.** Out of scope; each store
  belongs to exactly one cluster.

## Next step (after this doc is approved)

Sub-task list, smallest first:

1. Verify reckon-db's behaviour when loaded but not joined to a
   cluster (Open Question #1).
2. Add the mode env var + supervisor branch behind a feature flag.
   Empty `reckon_gateway_clusters_sup` (no connectors) gates the rest.
3. Implement `reckon_gateway_cluster_connector` against the parksim
   cluster (single entry in `clusters.eterm`).
4. Add `reckon_gateway_catalog` + `reckon_gateway_dispatch`; wire
   one gRPC handler (e.g. `ListStores`) end-to-end.
5. Smoke test: `lazyreckon --endpoint <new-gateway>:50051` shows the
   four parksim stores.
6. Roll out the dispatch switch across the remaining gRPC handlers.
7. Add `AdminService.ReloadCatalog` + `GetCatalogStatus`.
8. Add a second cluster to `clusters.eterm` (e.g. the embedded
   reckon-gateway cluster itself, treating it as just another
   cluster) and verify both visible in lazyreckon.
9. Decide WatchStores phase-2 streaming aggregator vs. snapshot
   polling.
