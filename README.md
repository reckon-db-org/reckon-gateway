<p align="center">
  <img src="docs/assets/logo.svg" alt="ReckonDB" width="120"/>
</p>

<h1 align="center">reckon-gateway</h1>

<p align="center">
  <strong>gRPC ingress for <a href="https://codeberg.org/reckon-db-org/reckon-db">ReckonDB</a>.</strong><br/>
  Federate N remote Erlang clusters over one endpoint, or boot a local store in the same image.
</p>

<p align="center">
  <a href="https://codeberg.org/reckon-db-org/reckon-gateway/releases"><img src="https://img.shields.io/badge/release-v0.7.0-1e40af" alt="release"/></a>
  <a href="https://github.com/reckon-db-org/reckon-gateway/pkgs/container/reckon-gateway"><img src="https://img.shields.io/badge/ghcr.io-image-0c4a6e" alt="image"/></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-475569" alt="license"/></a>
  <img src="https://img.shields.io/badge/erlang-OTP%2027%2B-92400e" alt="erlang"/>
  <a href="https://buymeacoffee.com/rlefever"><img src="https://img.shields.io/badge/Buy%20Me%20A%20Coffee-support-yellow.svg" alt="sponsor"/></a>
</p>

---

## What it is

`reckon-gateway` is a single OCI image that exposes the [ReckonDB](https://codeberg.org/reckon-db-org/reckon-db) event-store API over gRPC. Polyglot clients (Go, .NET, Rust, Python) get the full feature surface without speaking Erlang dist.

Three operational modes, selected by environment at boot:

| Mode | `STORE_ENABLED` | `CLUSTERS_PATH` | Use case |
|---|---|---|---|
| **Catalogue** (default) | `false` | set | Federate N remote ReckonDB clusters over one gRPC endpoint. Gateway holds no data. |
| **Embedded** | `true` | unset | One container = one ReckonDB store, served over gRPC. |
| **Hybrid** | `true` | set | Local store **and** federated remote clusters from the same endpoint. |

![architecture overview](docs/assets/architecture.svg)

## Quick start

### Pull the image

```bash
podman pull ghcr.io/reckon-db-org/reckon-gateway:0.7.0
```

### Run embedded (one container, one store)

```bash
podman run -d --name reckon-gw \
  -p 50051:50051 \
  -v reckon-data:/data \
  -e RECKON_GATEWAY_STORE_ENABLED=true \
  -e RECKON_GATEWAY_STORE_ID=my_store \
  -e RECKON_GATEWAY_LOCAL_CLUSTER_ID=local \
  -e RECKON_GATEWAY_DIST_HIDDEN_FLAG=-hidden \
  ghcr.io/reckon-db-org/reckon-gateway:0.7.0
```

### Run catalogue (federate remote clusters)

```bash
podman run -d --name reckon-gw \
  -p 50051:50051 \
  -v /etc/reckon-gateway/clusters.eterm:/etc/reckon-gateway/clusters.eterm:ro \
  -e RECKON_GATEWAY_DIST_HIDDEN_FLAG=-hidden \
  ghcr.io/reckon-db-org/reckon-gateway:0.7.0
```

> Set `RECKON_GATEWAY_DIST_HIDDEN_FLAG=-hidden` for catalogue and embedded-single deployments so the gateway is invisible to peers' `nodes/0` and `pg` sync doesn't leak across cookie-disjoint clusters. **Leave empty** when running embedded `STORE_MODE=cluster` (gateway containers in a Ra quorum need mutual pg visibility). See [docs/env-contract.md#hidden-node-flag](docs/env-contract.md#hidden-node-flag).

See [docs/clusters-eterm.md](docs/clusters-eterm.md) for the `clusters.eterm` schema.

### Call from a client

```go
conn, _ := grpc.NewClient("localhost:50051", grpc.WithTransportCredentials(insecure.NewCredentials()))
client := streampb.NewStreamServiceClient(conn)

resp, _ := client.AppendEvents(ctx, &streampb.AppendEventsRequest{
    StoreId:         "my_store",
    StreamId:        "user-7c4b9...",
    ExpectedVersion: -1,
    Events: []*streampb.ProposedEvent{{
        EventType: "user_registered_v1",
        Data:      []byte(`{"name":"Alice"}`),
    }},
})
```

Full example: [docs/examples/go-quickstart.md](docs/examples/go-quickstart.md).

## gRPC services

| Service | Description |
|---|---|
| `StreamService` | Append, read, list, delete event streams |
| `SubscriptionService` | Persistent server-streaming subscriptions |
| `SnapshotService` | Aggregate state snapshots |
| `TemporalService` | Time-based event queries |
| `SchemaService` | Event schema registration + upcasting |
| `AdminService` | Store inspection, scavenging, stream links |
| `StoresService` | Store enumeration via the catalogue |
| `HealthService` | Health checks, cluster diagnostics, memory pressure |
| `DcbService` | Dynamic Consistency Boundary: tag-filter conditional append + context read *(0.7.0+, requires reckon-db 3.1.1+ backing)* — see [the DCB guide](https://codeberg.org/reckon-db-org/reckon-db/src/branch/main/guides/dcb.md) |

Proto definitions are the source of truth and live in [reckon-proto](https://codeberg.org/reckon-db-org/reckon-proto). The gateway fetches them as a rebar3 dep at build time.

## Documentation

Full index: **[docs/README.md](docs/README.md)** , audience-grouped, with suggested reading orders.

Quick jumps:

- [Architecture](docs/architecture.md)
- [Environment contract](docs/env-contract.md) (incl. `RECKON_GATEWAY_DIST_HIDDEN_FLAG`)
- [Embedded mode](docs/embedded-mode.md)
- [`clusters.eterm` reference](docs/clusters-eterm.md)
- [Building from source](docs/building.md)
- [Go client quick start](docs/examples/go-quickstart.md)

## Versioning

| Component | Version (2026-05) |
|---|---|
| `reckon_gateway` | 0.7.0 |
| `reckon_gater` (deps) | ~> 2.2 |
| `reckon_db` (deps, opt) | ~> 3.0 |
| Erlang/OTP | 27+ |

Pin to the semver tag (`:0.7.0`) for reproducible deploys; `:latest` tracks `main`.

## License

Apache-2.0 , see [LICENSE](LICENSE).
