# Architecture

`reckon-gateway` is a gRPC ingress that dispatches every request to a ReckonDB store via Erlang dist (`rpc:call/4`). The store can live anywhere , the same image works as a pure federation gateway, an embedded-store backend, or both at once.

![three modes](assets/architecture.svg)

## Layers

```
gRPC client (Go/.NET/Rust/Python)
    | HTTP/2 (cowboy via emqx/grpc-erl)
    v
reckon_gateway_*_service  (one module per proto Service)
    | proto -> reckon_gater_api function call
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

The dispatcher consults the catalogue, picks a member, and does `rpc:call/4`. Per-peer cookies for remote clusters are set at runtime by `reckon_gateway_cluster_connector` before each dial , the BEAM's default cookie is unused for federation. In embedded mode the local connector resolves `store_id` to `members = [node()]`, so the same `rpc:call/4` path stays on-node (BEAM short-circuits this internally; Phase 3 of the hybrid plan considers a further optimisation).

## Boot sequence

```
reckon_gateway_sup (one_for_one)
  ├── reckon_gateway_catalogue
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
