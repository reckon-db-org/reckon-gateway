# DESIGN: reckon-gateway as a multi-cluster catalogue

**Status:** draft (no code yet)
**Author:** session 2026-05-19
**Audience:** Raf
**Supersedes:** [DESIGN_RECKON_GATEWAY_PROXY_MODE.md](DESIGN_RECKON_GATEWAY_PROXY_MODE.md) (historical only)

## Problem

Today reckon-gateway bundles two roles in one process:

1. **Data plane** — joins a clustered reckon-db via multicast gossip
   (`RECKON_DB_STORE_MODE=cluster`), holds local stores, owns workers.
2. **Ingress** — terminates gRPC and resolves each request to a
   local-or-cluster worker via `pg`.

Conflating "where the data lives" with "where clients connect" works
when the two coincide. It does not work when the lab has multiple
disjoint event-store-bearing clusters — each cookie-isolated — that
the operator wants to browse from one endpoint.

Concrete motivating case: the four `hecate-parksim-*` releases on
`beam00..03` carry their own embedded reckon-db with stores like
`parksim_entry2exit_store`. The current 5-node reckon-gateway cluster
carries its own. A future `hecate-marketplace` adds a third.
lazyreckon today cannot see all of these through one endpoint.

## Goal

Redefine reckon-gateway as a **pure catalogue gateway**. It is no
longer a reckon-db cluster member. It is:

- An Erlang dist node configured to connect to N disjoint clusters
  concurrently via per-peer cookies (`erlang:set_cookie(Node, Cookie)`).
- An aggregator: it asks each cluster's `reckon_gater` /
  `reckon_db_store_registry` for its live store list and merges the
  results.
- A gRPC ingress: `ListStores` returns the merged catalogue; every
  data RPC is routed via Erlang dist `rpc:call` to a healthy member
  of the cluster that owns the requested `store_id`.

store_ids are **ephemeral** — populated by `reckon_gater` on each
cluster as owner processes come and go. The gateway's config carries
only **clusters** (cookie + seed + optional `cluster_id` label).
Cookies never leave the gateway's memory.

This is a refactor of reckon-gateway, not an addition. The current
"data plane" role is dropped entirely.

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

One endpoint, three clusters visible, all their stores browsable.

## Non-goals

- **No protocol-level cluster naming.** `cluster_id` is operator-side
  metadata returned by `ListStores`; the on-wire schema treats it as
  an opaque routing tag.
- **No authn / authz at the gRPC layer.** Same posture as today
  (LAN-trust). The multi-cluster view increases blast radius if the
  gateway port is reachable beyond intended operators; flagged in
  Open Questions.
- **No HA / N+1 redundancy.** Two catalogue gateways with the same
  config form an obvious A/A pair (each connects independently to all
  clusters); the lazyreckon client picks one endpoint.
- **No store_id disambiguation across clusters.** store_ids are
  ephemeral, populated by each cluster's `reckon_gater` as owner
  processes come and go. When two clusters happen to expose the same
  store_id, the gateway logs the collision and rejects the later
  entry from the merged catalogue (first-seen wins). Operator's
  responsibility to rename in the offending service.

## Today's wiring (annotated, for context)

From the prior survey:

- `reckon_gateway_app.erl:11` boots `reckon_gateway_sup`.
- `reckon_gateway_sup.erl:14-51` registers nine gRPC services, each
  bound to a handler module.
- Cluster join is implicit through `sys.config` and reckon-db's own
  multicast discovery (`RECKON_DB_STORE_MODE`,
  `RECKON_DB_CLUSTER_MULTICAST_ADDR`, `RECKON_DB_CLUSTER_SECRET`).
- Every gRPC handler shares the same shape:

  ```erlang
  Foo(#{store_id := StoreIdBin, ...} = Req, _Stream) ->
      {ok, StoreId} = reckon_gateway_convert:try_store_id(StoreIdBin),
      reckon_gater_api:some_op(StoreId, Args)
  ```

  `reckon_gater_api` does `route_call → select_worker → pick_worker`
  over `pg` groups keyed by `{reckon_db_store, StoreId}`.
- `reckon_gateway_stores_service` reads from
  `reckon_db_store_registry` (the local cluster's replicated registry).

Catalogue mode keeps the gRPC server + the per-handler store_id
extraction, replaces everything below.

## Architecture

### Operating model

The gateway:

1. Starts the gRPC server (unchanged).
2. Starts a `clusters_sup` from `clusters.eterm`. One connector
   gen_server per cluster.
3. Each connector: `erlang:set_cookie(Seed, Cookie)`, then
   `net_adm:ping(Seed)`, then `rpc:call(Seed, erlang, nodes, [])` to
   learn the cluster's member list, then explicit
   `set_cookie + connect_node` for each member. Sets
   `dist_auto_connect = never` on the gateway itself so accidental
   auto-connects with the wrong cookie don't fire.
4. Periodically (default 30s) each connector re-asks its cluster:
   - `rpc:call(Member, erlang, nodes, [])` for member changes.
   - `rpc:call(Member, reckon_db_store_registry, list_stores, [])`
     for live store_ids.
5. Each connector calls `reckon_gateway_catalogue:publish(ClusterId,
   StoreIds)` after every refresh. The catalogue rebuilds its view
   from per-cluster publishes.

### Catalogue aggregator

A single gen_server with the live view:

```
#state{
    catalogue = #{StoreId => ClusterId, ...},   %% ephemeral, rebuilt per tick
    clusters  = #{ClusterId => #cluster_info{...}, ...}
}.
```

API:

```erlang
lookup(StoreId)              -> {ok, ClusterId, Members} | {error, not_found | unreachable}.
list_all()                   -> [{StoreId, ClusterId, Status}, ...].
publish(ClusterId, StoreIds) -> ok.                 %% from connector
remove(ClusterId)            -> ok.                 %% cluster retired
```

`publish/2` is the only mutator. Aggregator diffs against the
previous tick: new entries appear, missing ones drop, collisions
keep the existing entry and log the conflict once per occurrence.

### gRPC handler shape

Every data handler changes from:

```erlang
Foo(#{store_id := StoreIdBin, ...}, _) ->
    {ok, StoreId} = reckon_gateway_convert:try_store_id(StoreIdBin),
    reckon_gater_api:some_op(StoreId, Args).
```

to:

```erlang
Foo(#{store_id := StoreIdBin, ...}, _) ->
    {ok, StoreId} = reckon_gateway_convert:try_store_id(StoreIdBin),
    reckon_gateway_dispatch:call(StoreId, {some_op, Args}).
```

`reckon_gateway_dispatch:call/2`:

```erlang
call(StoreId, {Fn, Args}) ->
    case reckon_gateway_catalogue:lookup(StoreId) of
        {ok, _ClusterId, Members} ->
            Member = pick_member(Members),
            case rpc:call(Member, reckon_gater_api, Fn, [StoreId | Args]) of
                {badrpc, Why}   -> {error, {rpc_failed, Why}};
                Result          -> Result
            end;
        {error, not_found}    -> {error, store_unknown};
        {error, unreachable}  -> {error, cluster_unavailable}
    end.
```

### Discovery handler

`StoresService.ListStores/GetStore/WatchStores` route through the
catalogue. `ListStores` returns the merged flat list:
`[{store_id, cluster_id, status}, ...]`. `WatchStores` phase-1 emits
a periodic snapshot; phase-2 wraps each cluster's registry watch via
dist subscription and re-emits.

### Admin RPCs

Two new RPCs land on `AdminService` (the same service that already
hosts `Scavenge`, `CreateLink` etc.). Both follow the existing admin
pattern — request, response, no streaming.

#### Proto

In `reckon-proto/reckon_admin.proto`:

```proto
service AdminService {
  // ... existing RPCs (Scavenge, CreateLink, ListLinks, etc.) stay ...

  rpc ReloadCatalogue (ReloadCatalogueRequest)
                      returns (ReloadCatalogueResponse);
  rpc GetCatalogueStatus (GetCatalogueStatusRequest)
                          returns (GetCatalogueStatusResponse);
}

message ReloadCatalogueRequest {
  // Empty for now. Future-proof: could carry an inline config blob
  // for environments where the gateway can't read a file.
}

message ReloadCatalogueResponse {
  repeated string added     = 1;  // cluster_ids newly connected
  repeated string removed   = 2;  // cluster_ids retired
  repeated string restarted = 3;  // cluster_ids whose config changed
  string error              = 4;  // populated only on bad config
}

message GetCatalogueStatusRequest {}

message GetCatalogueStatusResponse {
  int32   catalogue_size  = 1;  // total distinct store_ids
  int64   gateway_uptime_ms = 2;
  repeated ClusterStatus clusters = 3;
}

message ClusterStatus {
  string  cluster_id   = 1;
  string  seed         = 2;  // e.g. "parksim_entry2exit@192.168.1.10"
  repeated string members = 3;
  int32   store_count  = 4;
  string  status       = 5;  // "up" | "unreachable" | "degraded"
  string  last_refresh = 6;  // ISO-8601
  string  last_error   = 7;  // populated when status != "up"
}
```

#### Handler wiring

`src/reckon_gateway_admin_service.erl` gains two clauses, each one
liner that delegates to the right module:

```erlang
reload_catalogue(_Req, _Stream) ->
    reckon_gateway_clusters_sup:reload_from_disk().

get_catalogue_status(_Req, _Stream) ->
    reckon_gateway_catalogue:status().
```

#### What each does

**`ReloadCatalogue`** — triggered by an operator after editing
`clusters.eterm`:

1. `reckon_gateway_clusters_sup:reload_from_disk/0` reads the file
   from `clusters_config_path` (sys.config).
2. Parses + validates: list of maps with `cluster_id`, `seed`,
   `cookie`. Malformed file → return `{error, {bad_config, Why}}`
   without touching live state.
3. Computes a diff against the current set of running connectors:
   - **added**: new `cluster_id` → start a connector via
     `supervisor:start_child/2`.
   - **removed**: gone `cluster_id` → `supervisor:terminate_child/2`.
     The connector's `terminate/2` calls
     `reckon_gateway_catalogue:remove/1` to drop the cluster's
     stores from the catalogue.
   - **restarted**: same `cluster_id` but cookie or seed differs →
     terminate + start. In-flight RPCs against this cluster see a
     brief `cluster_unavailable` window.
4. Returns the diff summary so the operator can confirm what
   changed.

Idempotent: calling twice with no file changes is a clean no-op
(`added=removed=restarted=[]`). Concurrent reloads serialise on the
sup's gen_server lock.

**`GetCatalogueStatus`** — read-only snapshot, no side effects:

1. `reckon_gateway_catalogue:status/0` returns the live aggregate:
   - Per cluster: `cluster_id`, `seed`, `members`, `store_count`,
     `status` (up | unreachable | degraded), `last_refresh` ISO
     timestamp, `last_error` (set when status ≠ up).
   - Gateway-level: `catalogue_size` (total distinct store_ids
     across all clusters), `gateway_uptime_ms`.
2. Used for:
   - Ops dashboards (poll every N seconds).
   - Verifying a `ReloadCatalogue` landed correctly.
   - Diagnosing why a store is invisible (cluster shows
     `unreachable` → fix the upstream service; cluster shows `up`
     but store missing → the owner process on the cluster isn't
     running).
3. Cheap call. Pure read from the catalogue gen_server's state. Safe
   to poll at 1-second granularity.

#### Operator-facing surface

How an operator actually invokes these. Three layers, choose one:

| Layer | Pro | Con |
|---|---|---|
| **`grpcurl` ad-hoc** | Zero new tooling; works today. | Verbose; requires knowing the proto. |
| **Small CLI in reckon-go** | One ergonomic binary: `reckon-gateway-admin {status,reload}`. | New code in reckon-go. |
| **lazyreckon command-palette** | UI-integrated; `:reload-catalogue` from inside the TUI. | UI churn; debatable whether end users should have admin powers. |

Recommendation: ship the `grpcurl` invocation as documented in the
README on day 1. Add a small subcommand to `lazyreckon` ('r' to
refresh, `Ctrl-R` to reload) as a follow-up if operators ask for it.
Don't write a separate admin CLI unless / until ops volume justifies.

#### Auth

Today the gateway has no auth on any gRPC RPC. Admin inherits the
same posture — anyone who can reach the gRPC port can call
`ReloadCatalogue`. For lab usage this is fine; for anything wider,
the gateway needs a bearer-token gate. Same Open Question as the
rest of the gRPC surface; not solved here.

#### Edge cases

- **Bad config file** (syntax error, missing fields): connectors
  keep running unchanged; response carries `error` with the parse
  failure; nothing is mutated.
- **Connector currently `unreachable` and unchanged in new config**:
  stays as-is; its retry loop keeps running.
- **In-flight RPC during a `removed` event**: connector termination
  closes the dist link; the in-flight `rpc:call` returns
  `{badrpc, nodedown}`; dispatch maps it to `cluster_unavailable`.
- **Duplicate `cluster_id` in new config**: `bad_config` error;
  state untouched.
- **clusters.eterm path unset / file missing**: same — `bad_config`
  with a clear error.

## SDK contract — wire-compatible

**reckon-gateway remains the single owner of the gRPC SDK API.** The
contract that the reckon-go SDK and lazyreckon consume is exactly the
contract reckon-gateway exposes today; this design preserves it.

What stays wire-identical:

- All nine gRPC services (`StreamService`, `StoresService`,
  `SubscriptionService`, `SnapshotService`, `HealthService`,
  `TemporalService`, `CausationService`, `SchemaService`,
  `AdminService`) and every RPC method on them.
- The reckon-proto schemas — request/response message types, field
  numbers, error codes, streaming semantics. No client recompilation
  needed.
- The per-handler `store_id` extraction + validation
  (`reckon_gateway_convert:try_store_id/1`). Clients send the same
  identifiers; the gateway resolves them differently internally.
- The `reckon-gater` Erlang dependency. reckon-gateway still
  imports the protocol types from reckon-gater; what changes is
  that the IMPLEMENTATION (`reckon_gater_api`) now runs on remote
  cluster members reached via dist `rpc:call`, instead of locally.

What changes from the SDK's perspective:

- `ListStores` returns an additional `cluster_id` field per entry
  (proto field with a fresh number; back-compatible — old clients
  ignore unknown fields).
- `AdminService` gains two new RPCs (`ReloadCatalogue`,
  `GetCatalogueStatus`); existing admin RPCs are unaffected.
- Per-RPC latency increases by one network hop (dist rpc to the
  owning cluster member). Documented; affects timeouts on long
  reads.
- New error returns: `store_unknown` (was previously rare),
  `cluster_unavailable` (new). Existing client error-handling
  paths typically already cover unknown-store; cluster-unavailable
  maps cleanly to `UNAVAILABLE` in gRPC status codes.

What does NOT change:

- The fact that reckon-gateway is the API surface for the reckon
  ecosystem. Clients connect to a gateway, not to individual
  reckon-db nodes. The data-plane refactor does not change that
  topology decision.

## Cookie discipline

**Cookies never cross the gateway → client boundary.** They are
Erlang's auth credential. The gateway holds them in `clusters.eterm`
(filesystem perms 0600) and in its own process memory; on the gRPC
side they are NEVER returned, even in error messages.

`cluster_id` is the only routing tag clients see. It's an
operator-assigned label, not the cookie. If the entire catalogue
leaks, the worst outcome is a list of cluster labels and store_ids,
not credentials.

## Config

In `config/sys.config.src`:

```erlang
{reckon_gateway, [
    {clusters_config_path, "${RECKON_GATEWAY_CLUSTERS_PATH}"},
    {refresh_interval_ms,  30000}
]},
{kernel, [
    {dist_auto_connect, never}
]}
```

`clusters_config_path` points at a separate file outside gitops,
e.g. `~/.hecate/secrets/reckon-gateway-clusters.eterm`:

```erlang
%% Erlang term file. Reloadable via AdminService.ReloadCatalogue.
[
    #{cluster_id => parksim,
      seed       => 'parksim_entry2exit@192.168.1.10',
      cookie     => <<"tKcKQnLjuoAVECwP9TcfA2AQJvA6QzL4ZcnykOihzQw">>},

    #{cluster_id => marketplace,
      seed       => 'marketplace_main@192.168.1.50',
      cookie     => <<"abcd...">>}
].
```

The split (sys.config has the path; secrets file has the actual
cookies) keeps cookies out of any image, gitops repo, or container
log.

## Patch surface

This is a refactor with subtractions and additions. Roughly:

**Removed:**

| File / surface | LOC |
|---|---|
| `reckon_db` dependency in `rebar.config` | -2 |
| `RECKON_DB_*` env vars + cluster block in `config/sys.config.src` | -25 |
| `reckon_gater_api`-via-local-`pg` routing inside each gRPC handler | -45 (5 LOC × 9 handlers) |

**Added:**

| File | LOC |
|---|---|
| `src/reckon_gateway_cluster_connector.erl` (new) | 120-180 |
| `src/reckon_gateway_catalogue.erl` (new) | 60-100 |
| `src/reckon_gateway_clusters_sup.erl` (new) | 30-50 |
| `src/reckon_gateway_dispatch.erl` (new) | 40-60 |
| `gen/reckon_admin.proto` additions (ReloadCatalogue + GetCatalogueStatus) | +20 |

**Modified:**

| File | LOC delta |
|---|---|
| `src/reckon_gateway_sup.erl` (boot `clusters_sup`; drop reckon-db wait) | +5 / -5 |
| `src/reckon_gateway_stores_service.erl` (use catalogue) | +30 / -15 |
| 8 other gRPC service handlers (replace `reckon_gater_api` calls with `dispatch`) | +5 each = 40 |
| `src/reckon_gateway_admin_service.erl` (ReloadCatalogue + GetCatalogueStatus) | +50 |
| `config/sys.config.src` (clusters config path + dist_auto_connect) | +10 |
| `rebar.config` (drop reckon-db; keep reckon-gater) | +1 / -2 |

**Net:** ~300-400 LOC added, ~100 LOC removed. The codebase shrinks
in functional surface area (no mode branching, no pg fallback, no
cluster-membership state held locally), even though raw LOC is
+200-300.

## Migration

Today: 5 reckon-gateway instances run a Khepri cluster across the
lab (laptop @ 192.168.1.100 + beam00..03). They hold demo event
data.

After: ONE catalogue gateway, deployed anywhere reachable by
operators. The four beam-resident reckon-gateways retire.

Steps:

1. Build the refactored reckon-gateway image. Its rebar.config no
   longer pulls reckon-db.
2. Operator writes `~/.hecate/secrets/reckon-gateway-clusters.eterm`
   listing the parksim cluster (cookie shared with the parksim
   releases on beam00..03).
3. Stop the existing reckon-gateway containers on laptop +
   beam00..03 (5 instances). Per prior session sign-off, archive
   their data dirs to `/bulk0/archive/reckon-gateway-<date>.tar.gz`
   then wipe the volumes. The data is demo content.
4. Start ONE new reckon-gateway container (catalogue) on the
   laptop. New port 50051 → catalogue endpoint.
5. `lazyreckon --endpoint laptop:50051`. Verify 4 parksim stores
   visible, browsable, eventable.
6. Add a second cluster to `clusters.eterm` when ready (e.g. when
   marketplace ships). `AdminService.ReloadCatalogue`. No gateway
   restart.

Rollback: stop the new container, restore the old image and the
archived data tarballs. Demo-grade rollback only; cleaner not to
need it.

## Operational model

| Concern | How it's handled |
|---|---|
| Add a cluster | Edit `clusters.eterm`, call `ReloadCatalogue`. No restart. |
| Remove a cluster | Same, in reverse. Connector terminates, catalogue drops its stores. |
| Cluster goes offline | Connector marks it `unreachable`; catalogue surfaces `status = unreachable`; data RPCs return `cluster_unavailable`. |
| Cluster comes back | Connector retries the seed; on success, repopulates members + stores; status flips to `up`. |
| New store appears in a live cluster | Connector's periodic refresh picks it up (<refresh_interval lag). |
| Store removed | Same path. |
| Cluster member moves | Refresh re-queries `nodes()`; old member pruned, new connected. |
| Cookie rotation | Operator updates `clusters.eterm`, `ReloadCatalogue`. Connector reconnects. Brief unavailability. |
| Duplicate store_id across clusters | Detected at refresh-merge. First-seen wins. Conflicting entry dropped + logged. Operator fixes by renaming in the offending service. |

## Open questions

1. **`dist_auto_connect = never` interaction with `monitor_node`.**
   `monitor_node/2` should still work on already-connected nodes
   regardless of auto-connect. Worth a smoke test.

2. **`WatchStores` streaming aggregation.** Phase-1: periodic
   snapshot pushed on the stream. Phase-2: subscribe to each
   cluster's `reckon_db_store_registry` events via dist and merge.
   Phase-1 is fine for lazyreckon, which already polls for safety.

3. **`rpc:call` timeout policy.** Local `reckon_gater_api` calls
   today are cheap; dist `rpc:call` crosses a network. Default 5s
   may be too short for streaming reads. Phase-1: 5s default + an
   explicit `streaming_op` variant that uses `infinity` with
   external cancellation. Document.

4. **Auth on the gRPC layer.** Single-cluster gateway today has
   none. Catalogue mode multiplies the blast radius. Out of scope
   for this design; flagged for whoever exposes the gateway outside
   a trusted LAN.

5. **Lazyreckon UX.** Adding a `cluster` column / grouping to the
   stores mode is a non-trivial UI change. Either ship the gateway
   change first and let existing lazyreckon render the flat list
   (cluster_id as just another column), or coordinate the
   lazyreckon update.

6. **Connector boot when seed is unreachable.** Should the gateway
   start (with that cluster as `unreachable`) or refuse to boot?
   Recommendation: start with the cluster offline; keep retrying;
   surface in `GetCatalogueStatus`. Refusing-to-boot couples
   gateway availability to upstream cluster availability.

## What this doc deliberately doesn't decide

- **`cluster_name` on the wire.** Per prior conversation, the
  client-side label stays client-side. The gateway returns
  `cluster_id` only because lazyreckon needs to group/disambiguate.
- **HA for the gateway.** Phase 2.
- **Cross-cluster transactions or queries.** Out of scope.

## Next step (after this doc is approved)

Sub-task list, smallest first:

1. Strip reckon-db from `rebar.config`; strip cluster env vars from
   `sys.config.src`. Verify the build succeeds and the gRPC server
   still starts (with no clusters configured, all RPCs return
   `store_unknown`).
2. Add `reckon_gateway_clusters_sup` and a stub connector that just
   logs its config and stays idle. Verify clusters.eterm parses.
3. Implement a real connector against the parksim cluster. Smoke
   test: `nodes()` on the gateway shows parksim members.
4. Add `reckon_gateway_catalogue`. Smoke test: `lookup` and
   `list_all` reflect the parksim store list.
5. Wire `reckon_gateway_dispatch` into `StoresService.ListStores`
   first. Smoke: `lazyreckon --endpoint gateway:50051` lists the
   parksim stores.
6. Wire dispatch into the remaining gRPC handlers.
7. Add `AdminService.ReloadCatalogue` + `GetCatalogueStatus`.
8. Add a second cluster to `clusters.eterm` (e.g. the old
   reckon-gateway cluster, treated as just another cluster) and
   verify both visible.
9. Decide `WatchStores` phase-2 streaming aggregator vs. snapshot.
