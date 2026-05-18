# Changelog

## 0.4.11 (2026-05-18)

### Fixed — remove_subscription / ack_event surface worker errors

Mirror of the 0.4.10 subscribe/create_subscription fix for the
remaining two subscription-lifecycle endpoints. Both handlers used
to do `ok = reckon_gater_api:...(...)`, a fire-and-forget cast
masking any worker-side failure.

With reckon-gater 2.1.3 / reckon-db 2.3.6, both calls are
synchronous and return `ok | {error, Reason}`. Handlers now
pattern-match:

- `remove_subscription/2` returns gRPC `Ok` on success (including the
  idempotent "already gone" case which the worker maps to `ok`) and
  `InvalidArgument` on transport / store errors.
- `ack_event/2` returns gRPC `Ok` on success and `InvalidArgument`
  on `{subscription_not_found, _}` (acking a removed subscription).

The cleanup-after-disconnect path in `subscribe/2` keeps the
discard-result shape — `remove_subscription` is idempotent on the
worker side and the worker logs any genuine error itself.

### Refactored — subscription-service handlers flatter

The handlers were 4+ levels deep (case-on-store-id → case-on-result).
`remove_subscription/2` and `ack_event/2` are split into two helper
clauses each (`handle_*` / `reply_*`), leaning on function-head
pattern matching instead of nested `case`.

### Changed — deps bumped

- `reckon_gater` `~> 2.1.3`
- `reckon_db` `~> 2.3.6`

## 0.4.10 (2026-05-18)

### Fixed — subscribe / create_subscription errors reach the client

Both `subscribe/2` (server-streaming) and `create_subscription/2`
(unary) used to do `ok = reckon_gater_api:save_subscription(...)`,
which was a fire-and-forget cast. If the worker rejected the
subscription (most notably `{invalid_filter, _}` from a malformed
selector), the gateway never knew — the cast returned `ok`
synchronously, the stream sat there forever, and the client saw
gRPC success while no events ever flowed.

With reckon-gater 2.1.2 / reckon-db 2.3.5, `save_subscription`
is synchronous and returns `{ok, Key} | {error, Reason}`. Both
handlers now pattern-match the result:

- `{ok, _Key}` → enter the streaming loop (subscribe) / return
  the assigned id (create_subscription).
- `{error, _}` → log the rejection, return gRPC
  `InvalidArgument` (status 3). The retry layer already
  whitelists `{invalid_filter, _}` and `{invalid_stream_id, _, _}`
  as non-retriable so the response is immediate.

### Updated

- Pinned `reckon_db` to `~> 2.3.5` (was `~> 2.3.4`).
- Pinned `reckon_gater` to `~> 2.1.2` (was `~> 2.1.1`).

## 0.4.9 (2026-05-18)

### Fixed — empty / malformed `store_id` returns InvalidArgument

`reckon_gateway_convert:store_id/1` used to throw `error/1` on
malformed input (empty binary, oversized, regex mismatch).
grpc-erl's handler wrapper caught the throw and surfaced
`Handle frame crashed` → gRPC `Internal`, which read as a
server bug even though the input was the client's fault.

New `reckon_gateway_convert:try_store_id/1` returns
`{ok, Atom} | {error, invalid_store_id}`. All 57 unary handler
entries across the 9 service modules now use it and return
gRPC `InvalidArgument` (status 3) on bad input. The throwing
`store_id/1` is kept for backwards compatibility and the few
internal callers that want fail-fast semantics.

Server-streaming `subscribe/2` in `reckon_gateway_subscription_service`
gets the same treatment.

## 0.4.8 (2026-05-18)

### Updated

- Pinned `reckon_db` to `~> 2.3.4` (was `~> 2.3.3` resolved).
- Pinned `reckon_gater` to `~> 2.1.1` (was `~> 2.1` resolved at 2.1.0).

2.3.4 + gater 2.1.1 together make the new stream-id validator
fail fast: malformed appends return gRPC `InvalidArgument`
within milliseconds instead of timing out after ~30s of
exponential-backoff retries.

Pins tightened so consumers can't accidentally regress.

## 0.4.7 (2026-05-18)

### Updated

- Pinned `reckon_db` to `~> 2.3.3` (was `~> 2.3.2` resolved).
  reckon-db 2.3.3 adds an append-time stream-id format validator
  that gates every write path through this gateway. Malformed
  ids (e.g. `partition$XYZ`, `test$basic-stream`) are now
  rejected with `{error, {invalid_stream_id, Reason, StreamId}}`,
  which the gateway already maps to gRPC `InvalidArgument`.

No source changes in the gateway itself; this is a deps-only
release so the deployed image cleanly reflects the upstream
ruleset.

## 0.4.6 (2026-05-17)

### Fixed — Subscription lag tolerates legacy + new field names

`reckon_gateway_subscription_service:get_subscription_lag/2` read
`#{lag, latest_version, ...}` from the gater response, but
`reckon_db_store_inspector:subscription_lag/2` emits
`#{lag_events, latest_position, ...}`. The mismatch returned a
zero-padded response on every successful lookup. Now accepts both
shapes (alongside the reckon-db 2.3.2 case_clause crash fix).

### Updated

- Pinned `reckon_db` to `~> 2.3.2` (was `~> 2.3.1`). Picks up
  three gateway-facing bug fixes: `by_stream` filter no longer
  rejects plain stream ids, `subscription_lag` no longer crashes
  the worker, `ReadSnapshot` with version=0 returns the latest.

## 0.4.5 (2026-05-17)

### Added — NIF acceleration end-to-end

Brings reckon-db 2.3.1's embedded Rust NIFs into the production
build, giving the cluster 3-15× speedups on the hot paths:

| Wrapper module | Speedup |
|----------------|---------|
| `reckon_db_crypto_nif` (Ed25519, SHA256) | 3-5× |
| `reckon_db_archive_nif` (LZ4 compression) | 5-8× |
| `reckon_db_hash_nif` (xxHash, FNV-1a) | 10-15× |
| `reckon_db_aggregate_nif` (vectorised aggregation) | 5-10× |
| `reckon_db_filter_nif` (regex/pattern) | 3-5× |
| `reckon_db_graph_nif` (graph algorithms) | 5-10× |

#### Changes

- `rebar.config`: `reckon_db` constraint bumped `~> 2.2 → ~> 2.3`
  (resolves to 2.3.1 from hex). reckon-db 2.3.x ships the six
  NIF crate sources under `native/` and the build-nifs.sh hook
  that compiles them.
- `Dockerfile` builder stage: installs `build-essential` plus the
  Rust 1.82.0 toolchain via rustup. Needed at build time so
  `rebar3 compile` can invoke `cargo build --release` for each
  reckon-db NIF crate. Final image size unchanged (this is a
  multi-stage build — only the assembled release is copied to
  the slim runtime image).

#### Operator notes

After deploying 0.4.5, the gateway boot logs should flip from

    [reckon_db_hash_nif] NIF not available (no_nif_found), using
                        pure Erlang - Community mode

to

    [reckon_db_hash_nif] NIF loaded - Enterprise mode

for all six modules. If you still see Community-mode logs the
cargo build step silently failed — check the builder-stage logs
for compilation errors. The fallback path stays functionally
correct in either case.

## 0.4.4 (2026-05-17)

### Changed — reckon_db dep back on hex

Switches `reckon_db` from the temporary git+tag pin (`v2.2.2`)
back to the standard hex constraint (`~> 2.2`). reckon_db 2.2.2
is now published on hex.pm; the git pin was only a stopgap during
0.4.3's live verification of the cluster Health RPC fix. No
behaviour change.

## 0.4.3 (2026-05-17)

### Fixed — HealthService cluster RPCs no longer hang

`HealthService.Check`, `VerifyClusterConsistency`,
`VerifyMembershipConsensus`, and `CheckRaftLogConsistency` had been
hanging the client until its deadline because
`reckon_db_gateway_worker` was calling into a `reckon_db_cluster`
module that didn't exist — a long-standing dangling reference left
over from reckon-db's `esdb_* → reckon_db_*` rename. Invisible
until the new reckon-go SDK actually started calling these RPCs.

Fixed in `reckon_db 2.2.1` by adding the missing module; this
release pins to that version. No gateway-side changes were
needed.

This release temporarily pulls reckon_db via git+tag (v2.2.1)
rather than hex; 0.4.4 will switch back to a hex constraint once
2.2.1 is published.

## 0.4.2 (2026-05-17)

### Removed — `AdminService.ListStores` handler

Aligns with `reckon-proto 0.2.0` which dropped the redundant
`AdminService.ListStores` RPC (superseded by `StoresService.ListStores`).
The handler in `reckon_gateway_admin_service.erl` was already
returning a buggy projection (treated the registry map as a list
of atoms); deleting it is cleanup, not a behaviour change.

`reckon_proto` dep bumped `v0.1.0` → `v0.2.0`.

## 0.4.1 (2026-05-17)

### Changed — Proto bundle moved to `reckon-proto`

The 10 `.proto` files that lived under `proto/` in this repo are
now consumed from the canonical [reckon-proto](https://codeberg.org/reckon-db-org/reckon-proto)
bundle as a pinned git dep (`v0.1.0`). The gateway is no longer
the source of truth for the wire contract.

Build-time behaviour unchanged: `grpc_plugin` regenerates the
same `_pb` and `_service_*` modules, just from the fetched dep
path instead of a local subdir. Wire-level behaviour unchanged.

Rationale: SDK consumers (`reckon-go`, future `reckon-ts`,
`reckon-rust`, etc.) need a single canonical proto repo to
depend on. Having the gateway also depend on it eliminates the
last source of drift.

## 0.4.0 (2026-05-17)

### Added — `StoresService` (cluster topology discovery)

New gRPC service `reckon.gateway.v1.StoresService` for discovery
of currently-running stores. Read-only — store lifecycle stays a
deployment concern (sys.config, hecate-gitops, podman units), the
same primitive that bootstraps `default_store`.

```
service StoresService {
  rpc ListStores  (ListStoresRequest)  returns (ListStoresResponse);
  rpc GetStore    (GetStoreRequest)    returns (GetStoreResponse);
  rpc WatchStores (WatchStoresRequest) returns (stream StoreEvent);
}
```

Backed by `reckon_db 2.2.0`'s cluster-wide `reckon_db_store_registry`
discovery + `subscribe/1` watcher API. The `WatchStores`
server-stream emits the current snapshot (optional) then live
`STORE_EVENT_TYPE_ANNOUNCED` / `STORE_EVENT_TYPE_RETIRED` events
as stores come and go anywhere in the cluster.

The proto-level surface is multi-store-ready — every per-store
service (`StreamService`, `SubscriptionService`, etc.) already
takes a `store_id` field. Operators add new stores by deploying
them; `StoresService` makes them discoverable.

### Bumps

- `reckon_db`: `~> 2.1` → `~> 2.2` (for the new discovery surface)

### Fixed — Server-streaming RPC plumbing (carried from 0.3.x patches)

Consolidated from previously-deployed images that never had a
formal 0.3.x release tag:

  - cowboy/cowlib mismatch: emqx/cowboy fork (2.9.0) routed
    `{trailers, _}` through `send_or_queue_data` which has no
    trailer clause in current cowlib → `case_clause` crash on
    every server-streaming RPC at stream end. Switched to
    mainline cowboy 2.15.0 + cowlib 2.16.1 + ranch 1.8.1.

  - `reckon_gateway_convert:subscription_type/1` only handled
    integer enums; gpb hands the handler proto atoms
    (`'SUBSCRIPTION_TYPE_STREAM'`). Added atom clauses.

  - `reckon_gateway_subscription_service:stream_events_loop/3`
    threaded the cowboy stream through `lists:foldl/3` but
    `grpc_stream:reply/2` returns `ok`. Second iteration crashed
    with `function_clause`. Switched to `foreach`.

## 0.3.0 (2026-05-16)

### Added — Env-var driven config for cluster deployments

`vm.args` and `sys.config` rewritten as `.src` templates that substitute environment variables at release startup. Enables multi-host cluster deployments without per-host image builds.

Variables (defaults set in the Dockerfile for standalone use):

| Variable | Default | Purpose |
|---|---|---|
| `NODE_NAME` | `reckon_gateway@127.0.0.1` | BEAM long node name (set per-host in cluster) |
| `RELEASE_COOKIE` | `reckon_gateway_default_cookie_change_in_prod` | Distribution cookie (same across cluster) |
| `RECKON_GATEWAY_PORT` | `50051` | gRPC listen port |
| `RECKON_DB_DATA_DIR` | `/app/data` | Base path for store data |
| `RECKON_DB_STORE_MODE` | `single` | `single` or `cluster` |
| `RECKON_DB_CLUSTER_PORT` | `45892` | UDP gossip discovery port |
| `RECKON_DB_CLUSTER_MULTICAST_ADDR` | `239.255.0.1` | Gossip multicast group |
| `RECKON_DB_CLUSTER_SECRET` | `reckon_db_default_secret_change_in_prod` | Gossip auth secret (same across cluster) |

### Changed

- `vm.args` switched from `-sname reckon_gateway` (short names) to `-name ${NODE_NAME}` (long names) — required for cross-host BEAM distribution.
- relx config in `rebar.config` switched to `sys_config_src` + `vm_args_src` directives.
- Bumped version 0.1.0 → 0.3.0 in both `relx` blocks (they were stale; CHANGELOG had moved to 0.2.0 without bumping the release version).

### Notes

The reckon-db cluster machinery (gossip discovery, store coordinator, node monitor, leader supervisor) already exists in reckon-db proper as a pure-Erlang port of the ExESDB libcluster-Gossip recipe. This release exposes the configuration surface so an operator can drive that machinery from outside the BEAM.

## 0.2.0 (2026-05-15)

### Added — Tamper-resistance fields on the wire + GetServerInfo

Layer 7 of the cross-package tamper-resistance work in
reckon-db/plans/PLAN_TAMPER_RESISTANCE.md. Exposes the chain
hash to polyglot gRPC clients (any language with a SHA-256
implementation can verify chain continuity locally) while
ensuring HMAC key material NEVER crosses the wire.

#### Proto schema additions

- `RecordedEvent.prev_event_hash` (field 12) — SHA-256 chain
  hash linking each event back to its predecessor. Empty bytes
  for legacy events.
- `SnapshotRecord.anchor_hash` (field 6) — chain hash of the
  event at the snapshot's version, captured at save time.
  Empty bytes for legacy snapshots.
- New `GetServerInfo` RPC on `HealthService` — returns the
  integrity algorithm identifier `"sha256-deterministic-etf-v1"`,
  per-store `integrity_enabled` flag, current writer
  `hmac_key_id` (1 in 0.2.0 — rotation arrives in reckon-db 2.2),
  reckon_db / reckon_gateway versions, and API compatibility
  version. The HMAC key bytes are NEVER returned.

#### Egress conversion

`reckon_gateway_convert` propagates the new integrity fields
and translates `undefined` to empty bytes for the wire. The
`#event.mac` and `#event.signature` fields are intentionally
NOT copied into the proto map: MAC is a symmetric secret bound
to the per-store key; leaking it across the wire defeats its
purpose. External authenticity (verifiable without the HMAC
key) is a future Ed25519 signature feature, not the storage
layer MAC.

#### GetServerInfo handler

`reckon_gateway_health_service:get_server_info/2` wraps
`reckon_db_integrity_key:is_enabled/1` and returns the
documented `ServerInfo` shape. Wrapped in a try/catch that
falls back to `integrity_enabled = false` on any error, so a
misconfigured gateway never advertises integrity that isn't
actually there.

#### Tests

- `reckon_gateway_convert_integrity_tests` (9 eunit): chain
  hash propagation (intact + legacy), **MAC must never appear
  in the proto map** (both as a known key AND as a substring
  in the serialised output), signature must never appear, full
  proto map field whitelist.
- `reckon_gateway_server_info_tests` (6 eunit): disabled /
  enabled state reporting, `key_id = 1` locked down, **HMAC
  key bytes must never appear in the response** (distinctive
  marker key substring scan), full response shape, API
  compatibility version is `"reckon.gateway.v1"`.

Full eunit: 15 tests pass.

### Changed

- Dependency constraints bumped: `reckon_gater` `~> 1.3.1` →
  `~> 2.1`, `reckon_db` `~> 1.7.5` → `~> 2.0`.
- Pre-existing technical debt cleared: all service modules
  migrated from the historical `esdb_gater_api` /
  `esdb_gater_types.hrl` names to the 2.x `reckon_gater_*`
  equivalents. Single mechanical sweep across `src/`. Required
  to consume reckon_gater 2.1.0's new schema fields.
- `src/reckon_gateway.app.src`: `{"GitHub", ...}` updated to
  `{"Codeberg", ...}` to match canonical hosting.

## 0.1.0 (2026-03-22)

Initial release.

### Services

- **StreamService** — Append, read, list, delete event streams
- **SubscriptionService** — Persistent subscriptions with server-streaming
- **SnapshotService** — Aggregate state snapshots
- **HealthService** — Health checks, cluster diagnostics, memory pressure
- **TemporalService** — Time-based event queries
- **CausationService** — Event lineage and correlation tracking
- **SchemaService** — Event schema registration and upcasting
- **AdminService** — Store inspection, scavenging, stream links
