# DESIGN: DCB gRPC Surface

**Status:** Draft, 2026-05-27
**Pairs with:** reckon-db 3.1.1, reckon-gater 2.3.1, reckon-evoq 2.2.1, evoq 1.19.0
**Repos touched:** reckon-proto, reckon-gateway, (later) reckon-go

---

## Goal

Expose the DCB (Dynamic Consistency Boundary) primitive of ReckonDB
through the gRPC gateway so non-BEAM clients (Go, .NET, Rust, Python)
can write Decisions with the same consistency guarantees the Erlang
`evoq_decision` behaviour gives BEAM clients.

DCB landed in the Erlang stack with `reckon-db 3.1.1`. From a
polyglot-client perspective the new primitive is invisible: gateway
RPCs cover the stream-version model only.

## Non-goals

- Server-side `evoq_decision_runtime` equivalent. v1 ships the two
  raw primitives (`AppendIfNoTagMatches`, `ReadDcbContext`) and lets
  the client orchestrate the read/decide/write loop. A
  "DecideAndAppend" server-side wrapper is a v2 candidate once we
  have polyglot usage shaped enough to know what shape it should
  take.
- Changes to the existing stream-version API. DCB lives alongside
  it as a separate `DcbService`; `StreamService` is untouched.
- DCB integrity field exposure. Integrity is local to the cluster
  (HMAC key is per-store, never crosses the gateway boundary).
  Clients see the same chain-hash + tag fields they already see
  on `RecordedEvent`.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│ Polyglot client (Go / .NET / Rust / Python)                  │
│   reckon-go (or sibling): DcbService stubs from reckon-proto │
└──────────────────────────────┬───────────────────────────────┘
                               │ gRPC, plaintext or mTLS
                               │
┌──────────────────────────────▼───────────────────────────────┐
│ reckon-gateway 0.7.0                                         │
│   reckon_gateway_dcb_service:                                │
│     - AppendIfNoTagMatches  -> reckon_gater_api:append_if_no_tag_matches/4
│     - ReadDcbContext        -> read DCB events + filter      │
└──────────────────────────────┬───────────────────────────────┘
                               │ Erlang dist / gen_server:call
                               │
┌──────────────────────────────▼───────────────────────────────┐
│ Backing ReckonDB cluster (reckon-db 3.1.1+)                  │
│   reckon_gater_api -> reckon_db_gateway_worker               │
│     -> reckon_db_dcb (khepri:transaction)                    │
└──────────────────────────────────────────────────────────────┘
```

## Proto contract (reckon-proto 0.4.0)

New file: `proto/reckon_dcb.proto`. See the file for the full IDL.
Highlights:

### `DcbService.AppendIfNoTagMatches`

Request:

```protobuf
message AppendIfNoTagMatchesRequest {
  string store_id = 1;
  TagFilter tag_filter = 2;
  sint64 seq_cutoff = 3;            // -1 means "saw nothing"
  repeated ProposedEvent events = 4;
}
```

Response uses a oneof to distinguish commit vs conflict — both are
successful evaluations of the request:

```protobuf
message AppendIfNoTagMatchesResponse {
  oneof result {
    Committed committed = 1;        // uint64 last_seq
    Conflict  conflict = 2;         // uint64 max_seq
  }
}
```

Conflict is **not** a gRPC error. It is a structured "no, your
context is stale". gRPC status codes are reserved for transport /
backend errors: `UNAVAILABLE` (cluster unreachable), `UNIMPLEMENTED`
(backing cluster pre-DCB), `INTERNAL` (anything else).

### `DcbService.ReadDcbContext`

Returns events matching a TagFilter from the DCB pseudo-stream
plus the highest-seq seen, ready to be passed back as the
`seq_cutoff` of a subsequent `AppendIfNoTagMatches`.

### `TagFilter` recursion

```protobuf
message TagFilter {
  oneof kind {
    TagList    match_any   = 1;    // {any_of,  [Tag]}
    TagList    match_all   = 2;    // {all_of,  [Tag]}
    FilterList conjunction = 3;    // {and_,    [TagFilter]}
    FilterList disjunction = 4;    // {or_,     [TagFilter]}
  }
}
```

Names chosen to avoid the `and`/`or` reserved-word collision while
keeping the Erlang term mapping one-to-one. Erlang side decodes:

```erlang
decode_filter({match_any,   #{tags    := T}}) -> {any_of, T};
decode_filter({match_all,   #{tags    := T}}) -> {all_of, T};
decode_filter({conjunction, #{filters := F}}) -> {and_, [decode_filter(X) || X <- F]};
decode_filter({disjunction, #{filters := F}}) -> {or_,  [decode_filter(X) || X <- F]}.
```

## Gateway changes (reckon-gateway 0.7.0)

### 1. New service handler

`src/reckon_gateway_dcb_service.erl`. Implements `dcb_service_bhvr`
generated from the proto. Two callbacks:

```erlang
-spec append_if_no_tag_matches(Req, Stream) -> {Reply, Stream} | {grpc_error, Status}.
-spec read_dcb_context(Req, Stream)        -> {Reply, Stream} | {grpc_error, Status}.
```

Body of `append_if_no_tag_matches/2`:

1. Resolve `store_id` -> backing cluster (catalogue mode) or local
   store (embedded/hybrid mode). Existing routing in
   `reckon_gateway_cluster_router` already covers this; just plug
   in.
2. Decode `tag_filter` proto -> Erlang term via `decode_filter/1`.
3. Decode `events` proto -> Erlang event maps via the same shim
   the existing `StreamService.AppendEvents` handler uses.
4. Call `reckon_gater_api:append_if_no_tag_matches(StoreId, Filter,
   Cutoff, Events)`.
5. Translate result:
   - `{ok, LastSeq}` -> `{Committed, LastSeq}`
   - `{error, {context_changed, MaxSeq}}` -> `{Conflict, MaxSeq}`
   - `{error, not_supported}` -> gRPC `UNIMPLEMENTED`
   - `{error, no_events}` -> gRPC `INVALID_ARGUMENT`
   - `{error, _Other}` -> gRPC `INTERNAL` + log

### 2. Dep bump

`rebar.config`: bump `reckon_gater` constraint to `~> 2.3`
(currently uses whatever it had). reckon-proto dep bumped to
`~> 0.4`.

### 3. Wire-up

`src/reckon_gateway_grpc_sup.erl` (or wherever services register):
add the new `dcb_service` route to the gRPC server's service list.

### 4. Tests

`test/reckon_gateway_dcb_service_SUITE.erl`:

- happy_path_commit
- conflict_returns_max_seq
- compound_filter_round_trip (proto -> erlang -> proto)
- empty_filter_match_any_with_zero_tags (edge: vacuous match)
- pre_dcb_backing_returns_unimplemented (use a mocked backing that
  returns `{error, not_supported}`)
- read_then_append_loop (the canonical Decision flow)

## Federation behaviour (catalogue mode)

reckon-gateway in catalogue mode federates N remote ReckonDB
clusters under one endpoint. Backing clusters can be on different
reckon-db versions. The gateway routes per `store_id`.

Backing clusters must run reckon-db 3.1.1+. If a `store_id` resolves
to a pre-DCB backing, the call surfaces as gRPC `UNIMPLEMENTED` with
a message naming the cluster version. Operators upgrade the backing
cluster; no partial-support code path lives in the gateway.

No probing / capability negotiation in v1. The first call to a
pre-DCB backing returns `UNIMPLEMENTED` and clients learn from
that.

## Versioning

| Repo | Current | Bump | Reason |
|------|---------|------|--------|
| reckon-proto | 0.3.1 | 0.4.0 | new service + messages |
| reckon-gateway | 0.6.2 | 0.7.0 | new RPC handlers + reckon_gater dep bump |
| reckon-go | (current) | minor | regenerate stubs from reckon-proto 0.4.0 |

Nothing in production uses DCB over gRPC yet. No compat shims, no
dual paths.

## Implementation phases

1. **proto** — land `reckon_dcb.proto`, regen Erlang stubs in
   reckon-proto, tag 0.4.0. (Files: `proto/reckon_dcb.proto`,
   regenerated `src/reckon_dcb_pb.erl`, CHANGELOG, app.src vsn.)
2. **gateway handler** — implement `reckon_gateway_dcb_service`,
   plug into the gRPC server, add CT suite, bump reckon_gater dep.
   Tag 0.7.0.
3. **reckon-go** — regenerate stubs, add a thin Go wrapper that
   handles the oneof-result idiomatically (Go callers expect
   `(committed, conflict, err)` rather than `(response, err)` for
   structured conflicts). Tag minor.
4. **example client** — extend the existing reckon-gateway example
   suite with a DCB uniqueness counter to exercise the full path.

Steps 2 and 3 can run in parallel after step 1 ships to hex.

## Open questions

1. **Federate-mode capability cache.** Worth caching per-cluster
   capability flags so we don't pay the UNIMPLEMENTED round-trip on
   every call to a pre-DCB cluster? Probably yes, but out of scope
   for v1 — defer until we see actual mixed-version deployments.
2. **Streaming read of context?** `ReadDcbContext` returns
   everything in one response. For large contexts, a server-
   streaming variant `StreamDcbContext` may be needed. Not v1.
3. **Audit-fact emission.** Should DCB writes through the gateway
   publish an audit fact to the integrity bus? Cross-cuts the
   existing audit story; defer to a separate doc.

## Out-of-scope but related

- A polyglot equivalent of `evoq_decision_runtime` (the read/
  decide/write loop with retry+backoff). Once we know what shape
  clients want, this could be a server-side RPC
  `DcbService.DecideAndAppend` that takes a callback URL or a
  WASM/Lua decision program; or stay client-side as an SDK
  helper in reckon-go / reckon-net. Park.
