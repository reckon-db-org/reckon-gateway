# Architecture

`reckon-gateway` is a dual-protocol ingress (gRPC + HTTP/JSON) that dispatches every request to a ReckonDB store via Erlang dist (`rpc:call/4`). The store can live anywhere , the same image works as a pure federation gateway, an embedded-store backend, or both at once.

## Two listeners, one dispatch path

The gateway opens two independent listeners at boot, both always on:

| Listener | Port env | Default | Serves |
|---|---|---|---|
| gRPC | `RECKON_GATEWAY_PORT` | `50051` | `reckon_gateway_*_service` modules (one per proto Service), started via `grpc:start_server/4` |
| HTTP/JSON | `RECKON_GATEWAY_HTTP_PORT` | `8080` | REST API, browser admin UI (`/admin`), SSE (`/v1/admin/events`); a Cowboy listener via `reckon_gateway_http_listener` |

Both funnel into the **same** `reckon_gateway_dispatch` -> `rpc:call/4` path below; the HTTP handlers (`reckon_gateway_http_*`) translate JSON to the same `reckon_gater_api` calls the gRPC service modules make. See [http-api.md](http-api.md) for the REST surface.

![three modes](assets/architecture.svg)

## Layers

```
gRPC client (Go/.NET/Rust/Python)        HTTP/JSON client (curl/browser/script)
    | HTTP/2 (cowboy via emqx/grpc-erl)       | HTTP/1.1+2 (cowboy)
    v                                         v
reckon_gateway_*_service              reckon_gateway_http_* handlers
    | proto -> reckon_gater_api call          | json -> reckon_gater_api call
    +-------------------+---------------------+
                        v
reckon_gateway_dispatch   (catalogue lookup -> rpc target)
    | rpc:call(TargetNode, reckon_gater_api, F, Args)
    v
reckon_gater_api          (worker registry on the OWNING node)
    | dispatch to the leader worker for StoreId
    v
reckon_db                 (Khepri store; Ra/Raft consensus)
```

The data plane lives on whatever BEAM owns the target `store_id`. In catalogue mode that's a remote BEAM; in embedded mode it's the same BEAM as the gateway. The gRPC service modules don't care.

## The catalogue

`reckon_gateway_catalogue` is an in-memory `gen_server` index from `store_id` to a `cluster_id + members + cookie + api_module` map. Two connectors publish into it:

| Connector | Source | Cadence |
|---|---|---|
| `reckon_gateway_cluster_connector` | Erlang dist `rpc:call/4` to each cluster in `clusters.eterm` | every `refresh_interval_ms` (default 30s) |
| `reckon_gateway_local_connector` | `reckon_db_store_registry:list_stores/0` on `node()` | every 5s |

The dispatcher consults the catalogue, picks a member, and does `rpc:call/4`. Per-peer cookies for remote clusters are set at runtime by `reckon_gateway_cluster_connector` via `erlang:set_cookie(Node, Cookie)` before each dial , the BEAM's default cookie is unused for federation. In embedded mode the local connector resolves `store_id` to `members = [node()]`, so the same `rpc:call/4` path stays on-node (BEAM short-circuits this internally; Phase 3 of the hybrid plan considers a further optimisation).

## Hidden-node bridging (catalogue mode)

When the gateway federates cookie-disjoint clusters, set `RECKON_GATEWAY_DIST_HIDDEN_FLAG=-hidden`. The BEAM starts as a hidden dist node and `pg` (which subscribes via `net_kernel:monitor_nodes(true)`, filtering hidden nodes) does not propagate state between the gateway and each cluster. Cluster A's `reckon_gater` pg scope stays isolated from cluster B's. Cookies still authenticate the per-peer dials; `-hidden` just ensures the non-transitive guarantee at the dist layer (see Erlang/OTP Distributed Erlang docs).

Embedded cluster mode (`STORE_MODE=cluster`) is the exception: gateway containers in a Ra quorum are dist peers of each other and **must** be mutually visible for pg sync. Leave the flag empty. See [env-contract.md#hidden-node-flag](env-contract.md#hidden-node-flag) for the full mode table.

## Boot sequence

```
grpc:start_server(reckon_gateway_grpc, RECKON_GATEWAY_PORT, Services, [])  (started by sup init, outside the child tree)

reckon_gateway_sup (one_for_one)
  ├── reckon_gateway_catalogue
  ├── reckon_gateway_http_listener        (Cowboy on RECKON_GATEWAY_HTTP_PORT: REST + admin UI + SSE)
  ├── reckon_gateway_clusters_sup
  │     └── reckon_gateway_cluster_connector @ ClusterId   (one per clusters.eterm entry)
  └── [if STORE_ENABLED=true]
      ├── reckon_gateway_store_starter      (transient; calls reckon_db_sup:start_store/1, returns ignore)
      └── reckon_gateway_local_connector    (polls registry -> catalogue:publish/2)
```

`reckon_gateway_store_starter` reads the embedded-store env contract via `reckon_gateway_config:embedded_store_spec/0`, builds a `#store_config{}`, and hands it to `reckon_db_sup:start_store/1`. The store joins `reckon_db`'s own supervision tree , the gateway only kicks the start.

## Why catalogue and embedded are independent flags

Catalogue mode (federate remotes) and embedded mode (boot a local store) are **composable, not toggled**. The dispatcher addresses every store by `store_id`. Whether that store happens to live in a remote BEAM, the local BEAM, or both, is a catalogue-resolution concern. The boot tree just decides which connectors are active.

That's the headline of the 0.6 hybrid design: same image, same gRPC surface, three operational shapes.

## What changes vs. 0.4.x

Pre-0.5, the gateway booted its own `reckon_db` store from `sys.config` and the dispatch path was in-process. 0.5 stripped the data plane entirely (catalogue-only). 0.6 brings the store back , but as an **opt-in env-gated** mode, and the dispatch path stays uniform (`reckon_gateway_dispatch` doesn't special-case local vs. remote).

If you're migrating from 0.4.x: there is no `{stores, [...]}` sys.config entry anymore. Set `RECKON_GATEWAY_STORE_ENABLED=true` plus `STORE_ID` + `DATA_DIR` and the embedded boot path takes over. See [embedded-mode.md](embedded-mode.md).
