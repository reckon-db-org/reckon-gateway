# Changelog

## 0.12.0 (2026-06-23)

**DCB read API + admin UI: Log, Tags, Event Types views.**

- Three new HTTP endpoints:
  - `GET /v1/stores/:store_id/dcb/log?from=0&limit=50` — paginated sequential
    read of DCB events; returns `{events, total_count, from_seq, limit}`.
  - `GET /v1/stores/:store_id/dcb/tags` — all tags from the by_tag index
    with event counts, sorted descending.
  - `GET /v1/stores/:store_id/dcb/event-types` — all event types from the
    by_event_type index with event counts, sorted descending.
- Admin UI gains three new DCB views:
  - **Log** — paginated event viewer with Prev/Next navigation;
    clicking `_dcb` in the Streams list now lands here.
  - **Tags** — tag list with counts; clicking a tag pre-fills Context Query.
  - **Event Types** — event type list; clicking a type pre-fills Context Query.
- Requires reckon-db ≥ 5.2.2 and reckon-gater ≥ 3.4.1.

## 0.11.0 (2026-06-22)

**HTTP/JSON API + embedded admin UI.**

- New Cowboy HTTP listener on `RECKON_GATEWAY_HTTP_PORT` (default 8080),
  separate from the gRPC port.
- `reckon_gateway_http` — shared helpers: `reply_json/3`, `reply_error/3`,
  `cors_preflight/1`, `decode_filter/1`, `event_to_json_map/1`,
  `parse_expected_version/1`, `dispatch_error/2`.
- `reckon_gateway_http_health` — `GET /v1/health`, `/v1/health/:store_id`,
  `/v1/server-info/:store_id`, `/v1/stores`, `/v1/stores/:store_id`.
- `reckon_gateway_http_streams` — full stream API:
  list, stream info/delete, events (read + append), version,
  `by-type`, `by-tags`, `by-metadata`, `global`.
- `reckon_gateway_http_dcb` — `POST /v1/stores/:store_id/dcb/context` and
  `POST /v1/stores/:store_id/dcb/append`. Conflict returns `200 {"conflict":
  {"max_seq": N}}` (not an HTTP error).
- `reckon_gateway_http_listener` — compiles cowboy routes and returns
  `ranch:child_spec/5`; started by `reckon_gateway_sup`.
- Admin UI at `/admin/` — minimal dark-theme HTML/JS (zero deps) served from
  `priv/static/admin/`; shows gateway health and store list on load.
- `sys.config.src`: new `{http_port, ...}` key fed by
  `RECKON_GATEWAY_HTTP_PORT`.
- `reckon_gateway_sup`: adds `reckon_gateway_http_listener:child_spec()` to
  the supervision tree before the clusters supervisor.

## 0.10.0 (2026-06-22)

**DCB `TagFilter.event_type_match` (reckon-proto 0.7.0 / reckon-db 5.2.0).**

- `TagFilter` oneof gains field 5: `event_type_match` (proto string).
  Decodes to `{event_type, binary()}` in `reckon_gater_types:tag_filter()`.
- `decode_filter/1`: new clause for `{event_type_match, T}`.
- `collect_event_types/1`: new exported helper — mirrors `collect_tags/1`
  for the event-type dimension.
- `do_read/4` (ReadDcbContext): now unions tag-index + event-type-index reads
  before client-side refinement. `collect_tags` returning `[]` no longer
  produces an empty result when `{event_type, T}` is the top-level filter.
- `event_matches/2`: handles `{event_type, T}` against both `#event{}` records
  and event maps.
- Generated `reckon_dcb_pb.erl` updated (reckon-proto → v0.7.0).
- Backed by `[by_event_type]` Khepri index (reckon-db 5.2.0+); pre-5.2.0
  events have no index entry and will not match.

## 0.9.0 (2026-06-08)

**Adopt reckon-db 5.0.0 (Model C + secondary index).**

- **`ReadByMetadata` handler.** `reckon_gateway_stream_service:read_by_metadata/2`
  routes the new `StreamService.ReadByMetadata` RPC (reckon-proto 0.6.0) to
  `reckon_gater_api:read_by_metadata/3`, bounding the response by `batch_size`.
  Mirrors the existing `read_by_tags` / `read_by_event_types` handlers.
- **Embedded-store index declaration.** New `RECKON_GATEWAY_STORE_INDEXES`
  env var (comma-separated `tags` / `event_type` / `meta:<key>`) is parsed into
  `store_config.indexes`, so a gateway-embedded reckon-db store can opt into
  the new secondary indexes. Empty/unset → no indexes (unchanged behaviour).
- **Dependency bumps:** `reckon_db ~> 4.0` → `~> 5.0` (required — 5.0.0 ships
  the index + `read_by_metadata` worker handler), `reckon_proto` `v0.5.0` →
  `v0.6.0` (the `ReadByMetadata` RPC). `reckon_gater ~> 3.0` already admits 3.2.0.

> **Upgrade note:** reckon-db 5.0.0 is a breaking on-disk layout change (Model C).
> A gateway running an **embedded** store must have that store **recreated** on
> upgrade (not just restarted). Catalogue-mode gateways (no embedded store) are
> unaffected — they route to remote BEAMs and never touch the layout.

## 0.8.0 (2026-06-07)

**Removed CausationService (BREAKING).**

Causation/correlation traversal is not an event-store concern. Deleted
the `CausationService` handler (`reckon_gateway_causation_service`), its
generated `reckon_causation_pb` / behaviour / client stubs, and the
service-map registration in the supervisor. `causation_id` /
`correlation_id` remain ordinary keys in event metadata — the gateway
relays metadata verbatim and never interprets it.

Bumps: `reckon_proto v0.5.0`, `reckon_gater ~> 3.0`, `reckon_db ~> 4.0`.

## 0.7.0 (2026-05-27)

**DCB (Dynamic Consistency Boundary) over gRPC.**

Exposes the DCB primitive shipped in reckon-db 3.1.1 to polyglot
clients via a new `DcbService`. Paired with `reckon-proto 0.4.0`.

### Added — `DcbService` (two RPCs)

- `AppendIfNoTagMatches(AppendIfNoTagMatchesRequest)` — conditional
  append under the DCB pseudo-stream. Server rejects when any event
  matching `tag_filter` has seq strictly above `seq_cutoff`. Returns
  a structured `oneof { Committed | Conflict }` so the conflict path
  is a successful response shape, not a gRPC error. gRPC status
  codes stay reserved for transport / backend errors (`UNAVAILABLE`,
  `UNIMPLEMENTED`, `INTERNAL`).
- `ReadDcbContext(ReadDcbContextRequest)` — read events matching a
  `TagFilter` from the DCB pseudo-stream, ordered by seq ascending,
  with the highest seq alongside. Use this to compute the
  `seq_cutoff` for a subsequent `AppendIfNoTagMatches`.

`TagFilter` is a recursive `oneof` with four variants
(`match_any` / `match_all` / `conjunction` / `disjunction`) mapping
1:1 to the Erlang term shape used by `reckon_gater_types:tag_filter()`.
`seq_cutoff` is `sint64` so the `-1` "saw nothing" sentinel is a
single byte on the wire.

Per-event semantics for `ReadDcbContext` mirror
`evoq_decision_runtime:match_filter/2` so polyglot consumers see
exactly the same matches the BEAM-side runtime sees.

### Error translation table

| dispatch reason         | gRPC code            |
|-------------------------|----------------------|
| `invalid_store_id`      | 3  `INVALID_ARGUMENT` |
| `malformed_tag_filter`  | 3  `INVALID_ARGUMENT` |
| `no_events`             | 3  `INVALID_ARGUMENT` |
| `store_unknown`         | 5  `NOT_FOUND`        |
| `not_supported`         | 12 `UNIMPLEMENTED`    |
| `cluster_unavailable`   | 14 `UNAVAILABLE`      |
| anything else           | 13 `INTERNAL`         |

Pre-DCB backing clusters (reckon-db &lt; 3.1.1) surface as
`UNIMPLEMENTED`. No partial-support path; operators upgrade the
backing.

### Federation behaviour (catalogue mode)

Backing clusters routed by `store_id` must run reckon-db 3.1.1+ to
serve DCB. Routing is unchanged from the stream-version API.

### Tests

- 24 eunit cases on the pure filter algebra (`decode_filter`,
  `collect_tags`, `event_matches`).
- 16 CT cases on the handler glue: happy path, conflict, all five
  error-code translations, compound-filter dispatch, vacuous filter,
  DCB-stream filtering, max_seq computation, end-to-end Decision
  loop (read → conflict → refresh → commit).

A live-cluster suite using a real reckon_db store is deferred until
reckon-db's CT harness lands a reusable test-cluster fixture.

### Dep bumps

- `reckon_proto`: v0.3.1 → v0.4.0 (adds `reckon_dcb.proto`).
- `reckon_gater`: constraint widened to `~> 2.3` (was `~> 2.2`).
  Requires the DCB wire types and `append_if_no_tag_matches/4`
  shipped in reckon-gater 2.3.1.

### Chore — edoc build fixed

`rebar3 ex_doc` was broken on 0.6.2 by two pre-existing
XML-parser-tripping `@doc` patterns (`` `reckon_gateway_cluster_<id>` ``,
``<<"tKcK...">>``) and two missing `extras` entries in `rebar.config`
(`guides/getting_started.md`, `guides/proto_reference.md`). All
fixed; ex_doc now runs clean as a release gate.

## 0.6.2 (2026-05-26)

**Optional hidden-node mode for clean multi-cluster bridging.**

Adds `RECKON_GATEWAY_DIST_HIDDEN_FLAG` env var (literal vm.arg
substitution; default empty). Set to `-hidden` for catalogue or
embedded-single deployments so the gateway starts as a hidden dist
node and OTP `pg` (used by `reckon_gater`'s worker_registry and
channel_server) doesn't sync state between cookie-disjoint clusters
through the gateway bridge.

Mechanism: OTP's `pg` subscribes via `net_kernel:monitor_nodes(true)`
which filters hidden nodes (verified in kernel-10.4/src/pg.erl), so a
hidden gateway is invisible to each cluster's pg scope. Per-peer
cookies (`erlang:set_cookie/2`, OTP-doc-prescribed pattern for
multi-cookie networks) authenticate each dial; `-hidden` adds the
non-transitivity guarantee.

**No smart default**, operators pick. Use it for:

- catalogue mode (federating cookie-disjoint clusters)
- embedded `STORE_MODE=single`
- hybrid with `STORE_MODE=single`

Leave empty for:

- embedded `STORE_MODE=cluster` (gateway containers are Ra quorum
  peers; mutual pg visibility required)
- hybrid with `STORE_MODE=cluster`

Also scrubbed an em-dash from `vm.args.src` (project rule + same
class of byte-level scanner risk that bit `sys.config.src` in 0.6.0).

See [docs/env-contract.md#hidden-node-flag](docs/env-contract.md#hidden-node-flag).

## 0.6.1 (2026-05-26)

**Docker: drop `ENV RECKON_DB_CLUSTER_SECRET=`.**

Lint-clean image. Docker's `SecretsUsedInArgOrEnv` rule flags ENV
declarations for secret-bearing variables (even empty). Removed the
declaration; cluster-mode operators supply it at runtime via compose
`environment:`, k8s `secretKeyRef`, systemd `EnvironmentFile=`, or
`--env-file`. Single-mode unaffected (multicast discovery is gated
on `STORE_MODE=cluster`).

No application code changed. Pin to `:0.6.1` (or `:latest`) for the
lint-clean image; `:0.6.0` still works but carries the warning.

## 0.6.0 (2026-05-26)

**Optional embedded reckon_db store.**

`reckon-gateway` is now a hybrid catalogue + embedded-store container.
When `RECKON_GATEWAY_STORE_ENABLED=true`, the gateway boots a local
`reckon_db` store via `reckon_db_sup:start_store/1` and advertises it
into the catalogue under the operator-set
`RECKON_GATEWAY_LOCAL_CLUSTER_ID`. When unset/false (the default), the
gateway behaves exactly like 0.5: pure catalogue + cluster_connector,
no local store.

One store per container. `RECKON_GATEWAY_STORE_MODE=single` for
standalone deployments, `cluster` to participate in Ra/Raft quorum via
`reckon_db`'s multicast or Kubernetes-DNS discovery (cluster mode
delegates fully to reckon_db; no new clustering code here).

New env vars (all default-off so 0.5 deployments need no change):

| Var | Meaning |
|---|---|
| `RECKON_GATEWAY_STORE_ENABLED` | Master switch (`true` opts in) |
| `RECKON_GATEWAY_STORE_ID` | Atom name of the local store |
| `RECKON_GATEWAY_DATA_DIR` | Persistent volume root (default `/data`) |
| `RECKON_GATEWAY_STORE_MODE` | `single` or `cluster` |
| `RECKON_GATEWAY_LOCAL_CLUSTER_ID` | Catalogue label for the local store |
| `RECKON_DB_CLUSTER_SECRET` | Multicast gossip secret (cluster mode only) |

Container changes: `VOLUME /data`, `EXPOSE 5000-5100` for Ra ports.
Dockerfile ENV defaults all off so a pulled `:latest` keeps catalogue
behaviour until the operator opts in.

Phase 1 of the hybrid mode plan; see
`plans/DESIGN_RECKON_GATEWAY_HYBRID_MODE.md`. Phase 2 (3-node cluster
CT) and Phase 3 (local-dispatch short-circuit) follow.

## 0.5.4 (2026-05-19)

**HealthService.Health: fix stores field encoding.**

The `stores` field in `HealthResponse` is `map<string, uint32>` per
the proto (cluster store-count per cluster). 0.5.3 returned
`map<binary, binary>` (cluster_status atom rendered as string),
which the proto encoder silently mis-encodes; the response never
reached the wire, the gRPC client timed out at 5s.

Fix: emit `cluster_id_bin => store_count_int`.

## 0.5.3 (2026-05-19)

**HealthService.Health: compute from catalogue, not dispatch.**

The `Health` RPC (gateway-wide, no store_id) was a leftover from the
pre-catalogue data-plane gateway. It dispatched the function `health`
with an empty args list — but the catalogue-mode dispatcher's
function head pattern is `call(Fn, [StoreId | _], _)` which requires
a non-empty list. Every call hit a function_clause crash and
returned `INTERNAL`.

Symptom: TUI dashboards (lazyreckon's "Connected" indicator polls
this RPC every refresh) saw permanent `rpc error: code = Internal
desc =` regardless of how healthy the underlying fleet actually
was. Surfaced via the new `gateway_rpc_coverage_SUITE` in reckon-e2e.

Fix: compute Health from the catalogue's own status snapshot. No
BEAM round-trip required — the gateway IS the layer that knows
whether catalogue connectors are up. Returns HEALTHY when at least
one configured cluster has status=up.

`stores` field now carries cluster_id → cluster_status mappings
(was per-store-id → unknown-detail in the legacy data-plane handler).

## 0.5.2 (2026-05-19)

**AdminService.GetStreamInfo: reject empty stream_id.**

`reckon_db_store_inspector:stream_info/2` (reckon-db 1.6.3) crashes
with `{case_clause, -1}` at line 85 when called with an empty stream
binary. The reckon-gater 1.x with_retry wrapper then retries 11
times with exponential back-off (~155 s wall time), blocking the
parksim worker gen_server and surfacing as `INTERNAL` to the gRPC
caller. lazyreckon polls `GetStreamInfo` during refresh; before this
guard, that single bad call could starve every concurrent RPC
against the same store for over two minutes.

Fix: gateway-side validation rejects empty stream_id with
INVALID_ARGUMENT before dispatching. The validation is cheap and
catches the bug at the boundary instead of propagating it to the
data plane.

## 0.5.1 (2026-05-19)

**HealthService: short-circuit single-mode stores.**

`VerifyClusterConsistency`, `VerifyMembershipConsensus`, `CheckRaftLogConsistency`,
and the per-store `Check` (which invokes `quick_health_check`) now consult the
catalogue's `mode` field first. If the store is single-mode the handler
returns `HEALTH_STATUS_HEALTHY` (or `CLUSTER_STATUS_HEALTHY`) with
`details.mode=single` immediately, without rpc-dispatching to the
owning BEAM.

Reason: single-mode reckon-db (the deployment shape used by the parksim
fleet) has no `reckon_db_cluster` module loaded. Dispatching the Raft-style
verification RPC triggers `{undef, reckon_db_cluster:verify_consistency/1}`
on the parksim worker, which the reckon-gater 1.x with_retry wrapper then
retries 11 times with exponential back-off (≈155 s). That retry storm
blocks the worker gen_server and starves concurrent `list_streams` /
`read_stream_forward` calls, surfacing as `INTERNAL` errors in client
tools (lazyreckon).

Fix is at the right layer: the gateway already knows each store's mode
via the catalogue connector's refresh tick. No parksim-side change
required.

New surface:
- `reckon_gateway_catalogue:store_mode/1 :: atom() -> {ok, single|cluster} | {error, not_found}`.

## 0.5.0 (2026-05-19)

**BREAKING.** Catalogue-mode refactor. Reckon-gateway no longer
carries data. It is a pure gRPC ingress that routes each request
via Erlang dist `rpc:call/4` to whichever BEAM owns the target
store. See `plans/DESIGN_RECKON_GATEWAY_CATALOGUE.md`.

### Step 1 — strip the data plane

This release covers only the first sub-task of the design: drop
the reckon-db dependency and the cluster-discovery env block.
Subsequent 0.5.x releases add the cluster connector, catalogue
aggregator, admin RPCs (`ReloadCatalogue`, `GetCatalogueStatus`)
and the per-handler dispatch.

### Removed

- `reckon_db` from `rebar.config` deps and from `reckon_gateway.app.src`
  `applications`. The gateway BEAM no longer loads reckon-db.
- `{reckon_db, [{cluster_port, ...}, {cluster_multicast_addr, ...},
  {stores, [...]}]}` block from `config/sys.config.src`.
- `RECKON_DB_DATA_DIR`, `RECKON_DB_STORE_MODE`, `RECKON_DB_CLUSTER_PORT`,
  `RECKON_DB_CLUSTER_MULTICAST_ADDR`, `RECKON_DB_CLUSTER_SECRET` env
  vars are no longer consumed. Setting them does nothing.

### Added

- `{reckon_gateway, [{clusters_config_path, "${RECKON_GATEWAY_CLUSTERS_PATH}"},
  {refresh_interval_ms, 30000}]}` placeholder in sys.config. When
  the path is unset or the file is missing, the catalogue boots
  empty and every data RPC will return `store_unknown` once the
  dispatch layer lands.
- `{kernel, [{dist_auto_connect, never}]}` so the gateway only
  connects to nodes it explicitly pings (per the design doc; avoids
  accidental cookie mismatches).
- `RECKON_GATEWAY_CLUSTERS_PATH` env var: absolute path to
  operator-curated `clusters.eterm` (cookies live there;
  out of gitops).

### Migration

The 5 orphan reckon-gateway:0.4.13 containers (laptop + beam00..03)
were retired in macula-internal/macula-demo commit 09dadf4. There
is no in-place upgrade path; the 0.5.0 image is intended for a
fresh deploy via macula-demo/infrastructure once the catalogue
implementation lands.

## 0.4.13 (2026-05-18)

### Fixed — scavenge errors surface the right gRPC code

The 0.4.12 admin scavenge handlers caught every worker error as
gRPC code 13 (Internal). Caller-side errors like
`{no_snapshot, _}`, `{stream_not_found, _}`, `{invalid_stream_id, _, _}`
now return code 3 (InvalidArgument).

## 0.4.12 (2026-05-18)

### Fixed — `ScavengeDryRun` against a stream without a snapshot is fast

The retry layer in reckon-gater 2.1.3 didn't treat `{no_snapshot, _}`
as a non-retriable error. `AdminService.ScavengeDryRun` against
a stream that doesn't exist (or has no checkpoint) hit the full
retry chain and ran out the gRPC deadline before surfacing the
real cause.

Bumps to reckon-gater 2.1.4 / reckon-db 2.3.7 which whitelist
`{no_snapshot, _}` alongside the other caller-side errors.

### Changed — deps bumped

- `reckon_gater` `~> 2.1.4`
- `reckon_db` `~> 2.3.7`

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
