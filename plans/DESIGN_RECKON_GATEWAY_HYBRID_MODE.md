# DESIGN: reckon-gateway as a hybrid catalogue + embedded store

**Status:** in implementation
**Author:** session 2026-05-26
**Audience:** Raf
**Supplements:** [DESIGN_RECKON_GATEWAY_CATALOGUE.md](DESIGN_RECKON_GATEWAY_CATALOGUE.md) — catalogue stays the substrate; embedded store is additive.
**Target release:** 0.6.0

## Problem

Today's `reckon-gateway` (0.5.x) is pure catalogue: gRPC ingress that
routes every request to a remote BEAM via Erlang dist `rpc:call/4`. It
holds no data, runs no Khepri/Ra. That's right for the
"federate-N-disjoint-clusters" use case but wrong for the
"one-container deploys an event-store-plus-gateway" use case.

A common deployment shape — single container, single store, exposed
over gRPC, configurable via env — falls between two existing options:
parksim-style services (embedded store, NO gRPC), and reckon-gateway
0.5 (gRPC, NO store). We want both in one image.

## Goal

`reckon-gateway` becomes a hybrid: **catalogue and/or embedded store**,
selected by env. The same container image, three operational modes:

| Mode | `RECKON_GATEWAY_STORE_ENABLED` | `RECKON_GATEWAY_CLUSTERS_PATH` | Use case |
|---|---|---|---|
| **Catalogue** (today's default) | false / unset | set | Federate N remote clusters over one gRPC endpoint. |
| **Embedded** | true | unset / empty | One container = one reckon-db store served via gRPC. |
| **Hybrid** | true | set | Local store + federated remote clusters. |

Composable, not toggle. The two flags are independent. Existing
catalogue deployments keep working unchanged (default
`RECKON_GATEWAY_STORE_ENABLED=false`).

## Architecture

Layer arrangement is unchanged from 0.5:

```
reckon_gateway_catalogue          (gen_server: StoreId → ClusterId index)
            ▲
            │ publish(ClusterId, #{stores, members, ...})
            │
            ├──── reckon_gateway_clusters_sup        (remote clusters, today)
            └──── reckon_gateway_local_connector     (local store, NEW)
                       │
                       │ polls reckon_db_store_registry:list_stores/0
                       ▼
                  reckon_db_sup:start_store/1        (NEW — boots when env says so)
                       │ (held by reckon_db's tree, owns Khepri/Ra)
                       ▼
                  Local Khepri store on /data
```

The catalogue is the existing read-model. Connectors are pluggable
data sources. The local connector is a sibling of the existing cluster
connector — same `publish/2` contract, different polling source.

The dispatch layer (`reckon_gateway_dispatch:call/2`) is unchanged.
When a request targets a store served locally, the catalogue resolves
it to `members = [node()]`. `rpc:call(node(), reckon_gater_api, F, A)`
works on the local node (with spawn overhead — a Phase 3 optimisation
exists to short-circuit).

## Env contract

### Always (catalogue + embedded)

- `NODE_NAME` — full Erlang node name (e.g. `reckon_gateway@host01.lab`)
- `RELEASE_COOKIE` — dist cookie; shared with cluster peers in cluster mode

### Catalogue (existing)

- `RECKON_GATEWAY_PORT` — gRPC listen port, default 50051
- `RECKON_GATEWAY_CLUSTERS_PATH` — path to clusters.eterm, optional

### Embedded store (new)

- `RECKON_GATEWAY_STORE_ENABLED` — `true` to enable; default `false`
- `RECKON_GATEWAY_STORE_ID` — atom name of the local store (e.g. `parksim_demo_store`)
- `RECKON_GATEWAY_DATA_DIR` — filesystem root for Khepri/Ra state (e.g. `/data`); must be writable + persistent
- `RECKON_GATEWAY_STORE_MODE` — `single` (standalone) or `cluster` (Ra quorum across peers); default `single`
- `RECKON_GATEWAY_LOCAL_CLUSTER_ID` — opaque label for the local store's `cluster_id` in the catalogue (e.g. `local`, `lab-beam`); operator-set

### Cluster-mode shared (when `STORE_MODE=cluster`)

- `RECKON_DB_CLUSTER_SECRET` — shared secret used by `reckon_db_discovery` multicast gossip
- `RECKON_DB_MULTICAST_ADDR` — optional override; default `239.255.0.1`

reckon-db's existing discovery (multicast LAN OR Kubernetes DNS) handles
peer discovery + Khepri cluster-join automatically. No new gateway code
beyond passing `mode = cluster` through `#store_config{}`.

## What changes in the gateway codebase

### New

- `src/reckon_gateway_store_starter.erl` — reads env, builds `#store_config{}`, calls `reckon_db_sup:start_store/1` when enabled.
- `src/reckon_gateway_local_connector.erl` — periodic poll of `reckon_db_store_registry:list_stores/0`, publishes to catalogue with operator-set `ClusterId`.

### Modified

- `rebar.config` — re-add `{reckon_db, "~> 3.0"}` dep. Comment notes it's now optional-via-env (no runtime start unless `RECKON_GATEWAY_STORE_ENABLED=true`).
- `src/reckon_gateway.app.src` — add `reckon_db` to applications list (started by OTP, but no stores active until starter calls `start_store/1`).
- `src/reckon_gateway_sup.erl` — conditional child specs for `store_starter` + `local_connector` based on env.
- `src/reckon_gateway_config.erl` — add `embedded_store_spec/0` returning `{ok, #{store_id, data_dir, mode, cluster_id}}` or `{ok, disabled}`.
- `config/sys.config.src` — new env var templates + defaults.
- `Dockerfile` — env defaults (all "off"), `VOLUME /data` declaration.

### Unchanged

- `reckon_gateway_dispatch` — works as-is. `rpc:call(node(), ...)` is correct semantics for local-served stores; optional short-circuit lands later (Phase 3).
- `reckon_gateway_catalogue` — generic, accepts any connector source.
- All 9 gRPC service modules.
- `reckon_gateway_clusters_sup` + existing connector.

## Phases

- **Phase 1** (this session): re-add dep + embedded store boot + local connector + env wiring + Dockerfile + single-mode CT smoke. Cluster mode achievable via env (multicast or K8s DNS supplied by reckon-db's discovery).
- **Phase 2**: 3-node cluster CT proving Ra quorum formation across containers.
- **Phase 3**: local dispatch short-circuit + 0.6.0 release.

## Non-goals (Phase 1)

- **Multi-store per container.** One container = one store. Multi-tenant ⇒ multi-container.
- **Mode migration on disk.** Switching `single → cluster` mid-life isn't supported; data layout differs. Deploy at the intended mode; don't flip.
- **Local dispatch short-circuit.** `rpc:call(node(), ...)` works; the optimisation comes later if profiled-justified.
