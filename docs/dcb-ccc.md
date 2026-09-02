# DCB + CCC queries

The gateway exposes two related advanced read/write surfaces over both gRPC (`DcbService`) and HTTP (`/v1/stores/:store_id/dcb/...`):

- **DCB** — Dynamic Consistency Boundary: conditional append + context read over a *tag/event-type filter* instead of a single stream. Lets you enforce an invariant that spans many streams without a lock.
- **CCC** — compound payload-indexed reads: look events up by a declared *payload field* (or a hash of several fields) rather than by stream or tag.

Both require a reckon-db 5.4+ backing store. The conceptual model for DCB lives in the upstream [reckon-db DCB guide](https://github.com/reckon-db-org/reckon-db/blob/main/guides/dcb.md); this page documents only what the gateway adds on top.

> History: DCB context/append landed early; the DCB introspection (log/tags/event-types) and CCC reads were added across gateway 0.10–0.16, with gRPC `CccReadByPayload`/`CccReadByPayloadHash` handlers in 0.14.0 and CCC index discovery in 0.16.0.

## Tag-filter algebra

Every DCB endpoint that takes a `tag_filter` uses the same JSON algebra (mirrors the proto `TagFilter` OneOf):

```json
{ "match_any": ["seat:12A", "seat:12B"] }   // any of these tags
{ "match_all": ["flight:LX42", "vip"] }      // all of these tags
{ "event_type": "seat_reserved_v1" }          // this event type
{ "and": [ {...}, {...} ] }                    // conjunction of sub-filters
{ "or":  [ {...}, {...} ] }                    // disjunction of sub-filters
```

A missing or malformed filter returns `400 {"error":"malformed_tag_filter"}` (HTTP) / the equivalent gRPC status.

## DCB read (context)

`POST /v1/stores/:store_id/dcb/context`

```json
// request
{ "tag_filter": { "match_all": ["flight:LX42", "seat:12A"] }, "batch_size": 1000 }
// response
{ "events": [ ...event objects... ], "max_seq": 87 }
```

Returns every DCB-stream event matching the filter and the highest sequence seen (`max_seq`, `-1` if none). `batch_size` `0` means "use the server cap" (10 000). This is the consistency context you read *before* a conditional append.

## DCB conditional append

`POST /v1/stores/:store_id/dcb/append`

```json
// request
{ "tag_filter": { "match_all": ["flight:LX42", "seat:12A"] },
  "seq_cutoff": 87,
  "events": [ { "event_type": "seat_reserved_v1", "tags": ["flight:LX42","seat:12A"], "data": {"pax":"Alice"} } ] }
// committed
{ "committed": { "last_seq": 88 } }
// rejected (someone else wrote a matching event past seq_cutoff)
{ "conflict": { "max_seq": 90 } }
```

The append commits **only if** no event matching `tag_filter` exists past `seq_cutoff`. A conflict is a normal `200` response with a `conflict` body (not an error): re-read the context at the new `max_seq` and retry. `seq_cutoff` of `-1` means "no event may match at all". Proposed events use the standard [proposed-event shape](http-api.md#proposed-event-shape-writes).

## DCB introspection

Read-only views over the DCB stream, used by the admin UI:

| Endpoint | Response |
|---|---|
| `GET /dcb/log?from=0&limit=50` | `{"events":[...],"total_count":N,"from_seq":N,"limit":N}` — paginated log; `limit` capped at 200 |
| `GET /dcb/tags` | `{"tags":[{"tag":"flight:LX42","count":12}, ...]}` |
| `GET /dcb/event-types` | `{"event_types":[{"event_type":"seat_reserved_v1","count":40}, ...]}` |

## CCC payload-indexed reads

CCC lets you address events by a **declared payload field** rather than by stream or tag. The store declares which payload fields are indexed:

- `{payload, Key}` — index a single payload field for equality lookups.
- `{payload_hash, [Key1, Key2, ...]}` — index a SHA-256 over an ordered set of fields, for composite lookups.

For an **embedded store** (the gateway hosting reckon-db), declare these in `store.eterm` — they cannot be expressed via `RECKON_GATEWAY_STORE_INDEXES` (that env var only declares `tags` / `event_type` / `meta:<key>`). See **[store-config.md](store-config.md)** for the file. For a **federated** store, the declaration lives in that store's own reckon-db config on its owning node.

Either way, the gateway only *reads* what the store declared — discover it with `GET /dcb/payload-indexes`.

### Discover what's declared

`GET /v1/stores/:store_id/dcb/payload-indexes`

```json
{ "payload": ["account_id", "flight_id"],
  "payload_hash": [ ["flight_id", "seat_no"] ] }
```

`payload` lists single-field indexes; `payload_hash` lists composite-index field combinations. Discovery requires reckon-gater 3.7+; on an older backend it returns `rpc_failed` and the admin UI falls back to manual key entry.

### Query by a single payload field

`GET /v1/stores/:store_id/dcb/by-payload?key=account_id&value=7c4b9&limit=1000`

```json
{ "events": [ ...events whose payload.account_id == "7c4b9"... ] }
```

`key` and `value` are required (`400 missing key` / `missing value` otherwise). `limit` is capped at 10 000.

### Query by a payload-hash combination

`POST /v1/stores/:store_id/dcb/by-payload-hash`

```json
// request — keys/values are positional and must be equal length
{ "keys": ["flight_id", "seat_no"], "values": ["LX42", "12A"], "limit": 1000 }
// response
{ "events": [ ...events whose (flight_id, seat_no) hash matches... ] }
```

`keys` and `values` must both be arrays of equal length (else `400`). The server hashes the ordered values to the same SHA-256 the index stores; the operator never sees the hash. `limit` is capped at 10 000.

## Errors

DCB/CCC endpoints share the gateway [error shape](http-api.md#error-shape). The most relevant:

- `501 not_supported` — the backing store predates DCB/CCC support (reckon-db < 5.4) or the index isn't declared.
- `400 malformed_tag_filter` — bad `tag_filter` JSON.
- `502 rpc_failed` — remote cluster RPC failed (e.g. `payload-indexes` discovery against an older node).
