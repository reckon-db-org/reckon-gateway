# Changelog

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
