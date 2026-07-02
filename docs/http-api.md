# HTTP/JSON API reference

The gateway serves a plain HTTP/JSON REST API on `RECKON_GATEWAY_HTTP_PORT` (default `8080`), alongside the gRPC listener on `RECKON_GATEWAY_PORT` (default `50051`). Both listeners always start; they expose the same underlying ReckonDB surface. Use HTTP when you don't want to generate protobuf stubs (curl, browser, shell scripts, quick experiments).

The HTTP listener also serves the [admin UI](admin-ui.md) at `/admin` and a Server-Sent Events stream at `/v1/admin/events`; both are documented separately.

## Conventions

- **Base URL**: `http://<host>:8080`
- **Content type**: requests with a body send `application/json`; all responses are `application/json` (except SSE).
- **CORS**: every endpoint answers `OPTIONS` preflight and returns `access-control-allow-origin: *`, so a browser app on another origin can call it directly.
- **`:store_id`** in a path is the store name (the embedded store's `RECKON_GATEWAY_STORE_ID`, or a `cluster_id`-scoped store from `clusters.eterm`). Invalid names return `400 {"error":"invalid_store_id"}`.

### Error shape

Every error is `{"error":"<reason>"}` with an HTTP status mapped from the dispatch reason:

| Status | Reason | Meaning |
|---|---|---|
| `400` | `invalid_store_id`, `invalid_json`, `no_events`, `malformed_tag_filter`, `missing ...` | Bad request |
| `404` | `store_unknown` | No such store in catalogue or embedded |
| `409` | `version_conflict` | Optimistic-concurrency failure on append |
| `501` | `not_supported` | Backend lacks the feature (e.g. DCB on a pre-5.4 store) |
| `502` | `rpc_failed` | Remote cluster RPC failed |
| `503` | `cluster_unavailable` | Target cluster is down |
| `500` | other | Unexpected |

### Event JSON shape

Reads return events as:

```json
{
  "event_id": "018f...",
  "event_type": "user_registered_v1",
  "stream_id": "user-7c4b9",
  "version": 0,
  "data": { "name": "Alice" },
  "metadata": { "correlation_id": "..." },
  "tags": ["account:7c4b9"],
  "timestamp": "2026-06-26T12:00:00Z",
  "epoch_us": 1782820800000000,
  "data_content_type": "application/json",
  "metadata_content_type": "application/json",
  "prev_event_hash": "<base64 or empty>"
}
```

`data`/`metadata` are returned as inline JSON when the content type is `application/json`; otherwise they are base64 strings. An empty/`undefined` payload is `null`.

### Proposed-event shape (writes)

When appending, each event in the `events` array is:

```json
{
  "event_type": "user_registered_v1",   // required
  "data": { "name": "Alice" },            // object (json) or omitted
  "metadata": { "correlation_id": "x" },  // optional
  "tags": ["account:7c4b9"],              // optional
  "event_id": "",                          // optional; server mints a UUIDv7 if empty
  "data_content_type": "application/json",
  "metadata_content_type": "application/json"
}
```

`event_type` is mandatory; a missing one yields `400 {"error":"missing_event_type"}`.

### Expected-version values (append)

`expected_version` accepts an integer or a symbolic string:

| Value | Int | Meaning |
|---|---|---|
| `"any"` | `-2` | No concurrency check (default) |
| `"no_stream"` | `-1` | Stream must not exist yet |
| `"exists"` | `-4` | Stream must already exist |
| `N` | `N` | Stream must be at exactly version `N` |

---

## Health + discovery

### `GET /v1/health`
Gateway aggregate status. No store id.
```json
{ "status": "healthy", "node": "reckon_gateway@...", "catalogue_size": 3, "timestamp_ms": 1782820800000 }
```
`status` is `healthy` if any catalogued cluster is up, else `degraded`.

### `GET /v1/health/:store_id`
Per-store health check.
```json
{ "status": "healthy", "details": {} }
```
`status` is `unhealthy` with `{"reason": "..."}` in `details` if the backing store fails its quick check.

### `GET /v1/server-info/:store_id`
Version + integrity advertisement.
```json
{
  "reckon_db_version": "5.4.0",
  "reckon_gateway_version": "0.16.1",
  "api_compatibility_version": "reckon.gateway.v1",
  "integrity_algo": "sha256-deterministic-etf-v1",
  "integrity_enabled": true,
  "hmac_key_id": 1
}
```

### `GET /v1/stores`
List every store the catalogue knows (one entry per store id). For a
cluster-mode store, `nodes` holds all replica nodes and `replica_count`
their number; `node` is the first-seen replica, retained for compatibility.
```json
{ "instances": [
  { "store_id": "my_store", "node": "parksim_leuven@192.168.1.10",
    "nodes": ["parksim_leuven@192.168.1.10", "parksim_leuven@192.168.1.11",
              "parksim_leuven@192.168.1.12"],
    "replica_count": 3, "mode": "cluster",
    "data_dir": "/data", "timeout_ms": 5000, "registered_at_us": 1782820800000000 }
]}
```
Pair with `GET /v1/stores/:store_id/cluster` to learn which replica is the
Ra leader.

### `GET /v1/stores/:store_id`
Same shape, filtered to one store id.

---

## Streams

### `GET /v1/stores/:store_id/streams`
List stream ids in the store.
```json
{ "stream_ids": ["user-7c4b9", "order-1a2b"] }
```

### `POST /v1/stores/:store_id/streams/:stream_id/events`
Append events.
```json
// request
{ "expected_version": "any",
  "events": [ { "event_type": "user_registered_v1", "data": { "name": "Alice" } } ] }
// response
{ "version": 0, "count": 1 }
```
`version` is the stream's new head version after the append. `409 version_conflict` if `expected_version` doesn't hold.

### `GET /v1/stores/:store_id/streams/:stream_id/events`
Read a single stream.

| Query | Default | Meaning |
|---|---|---|
| `from` | `0` | Start version |
| `limit` | `100` | Max events |
| `dir` | `forward` | `forward` or `backward` |

```json
{ "events": [ ... ], "count": 12 }
```

### `GET /v1/stores/:store_id/streams/:stream_id/version`
```json
{ "version": 11 }
```

### `DELETE /v1/stores/:store_id/streams/:stream_id`
```json
{ "deleted": true }
```

---

## Cross-stream indexed reads

These require the corresponding secondary index to be declared via `RECKON_GATEWAY_STORE_INDEXES` (see [env-contract.md](env-contract.md)) for an embedded store.

### `GET /v1/stores/:store_id/events/by-type`
| Query | Default | Meaning |
|---|---|---|
| `types` | (required) | Comma-separated event types: `a,b,c` |
| `limit` | `0` (all) | Max events |

Missing `types` → `400`. Returns `{ "events": [...], "count": N }`.

### `GET /v1/stores/:store_id/events/by-tags`
| Query | Default | Meaning |
|---|---|---|
| `tags` | (required) | Comma-separated tags |
| `match` | `any` | `any` or `all` |
| `limit` | `0` (all) | Max events |

### `GET /v1/stores/:store_id/events/by-metadata`
| Query | Default | Meaning |
|---|---|---|
| `key` | (required) | Metadata key |
| `value` | (required) | Metadata value |
| `limit` | `0` (all) | Max events |

### `GET /v1/stores/:store_id/events/global`
Read the global ordered log.
| Query | Default | Meaning |
|---|---|---|
| `offset` | `0` | Global position |
| `limit` | `100` | Max events |

---

## DCB + CCC

Dynamic Consistency Boundary and Compound-Condition / payload (CCC) endpoints live under `/v1/stores/:store_id/dcb/`. They have their own conceptual guide: **[dcb-ccc.md](dcb-ccc.md)**. Summary of the wire surface:

| Method + path | Body / query | Response |
|---|---|---|
| `POST /dcb/context` | `{"tag_filter": {...}, "batch_size": N}` | `{"events": [...], "max_seq": N}` |
| `POST /dcb/append` | `{"tag_filter": {...}, "seq_cutoff": N, "events": [...]}` | `{"committed":{"last_seq":N}}` or `{"conflict":{"max_seq":N}}` |
| `GET /dcb/log` | `?from=0&limit=50` (limit capped at 200) | `{"events":[...],"total_count":N,"from_seq":N,"limit":N}` |
| `GET /dcb/tags` | — | `{"tags":[{"tag":"...","count":N}]}` |
| `GET /dcb/event-types` | — | `{"event_types":[{"event_type":"...","count":N}]}` |
| `GET /dcb/by-payload` | `?key=K&value=V&limit=N` | `{"events":[...]}` |
| `POST /dcb/by-payload-hash` | `{"keys":[...],"values":[...],"limit":N}` | `{"events":[...]}` |
| `GET /dcb/payload-indexes` | — | `{"payload":["k",...],"payload_hash":[["k1","k2"],...]}` |

### Tag-filter JSON algebra

`tag_filter` mirrors the proto `TagFilter` OneOf:

```json
{ "match_any": ["tag1", "tag2"] }
{ "match_all": ["tag1", "tag2"] }
{ "event_type": "seat_reserved_v1" }
{ "and": [ {...}, {...} ] }
{ "or":  [ {...}, {...} ] }
```

A missing or unrecognised filter returns `400 malformed_tag_filter`.

---

## Live event stream (SSE)

`GET /v1/admin/events` streams `text/event-stream`. See [admin-ui.md](admin-ui.md#server-sent-events) for the named-event payloads.
