# Admin UI + live event stream

The HTTP listener (`RECKON_GATEWAY_HTTP_PORT`, default `8080`) serves a single-page browser admin UI and a Server-Sent Events stream. No build step, no extra service: the UI is a static `index.html` shipped in the image at `priv/static/admin/`, and it drives itself entirely off the [HTTP/JSON API](http-api.md).

## Opening it

```
http://<host>:8080/admin
```

`/admin`, `/admin/`, and `/admin/<asset>` are all served from `priv/static/admin/`. When running in a container, publish the HTTP port: `podman run -p 8080:8080 ...`.

There is no authentication in front of the admin UI or the REST API. Treat port `8080` as an operator-only surface: bind it to a private interface, or front it with a reverse proxy that handles auth. Do not expose it to the public internet.

## Views

The left nav groups views into four sections:

**Gateway**
- **Overview** — gateway status (`healthy`/`degraded`), registered-store count, BEAM node, live-updated from the SSE stream.
- **Clusters** — per-cluster federation state from the catalogue: members, store count, status, last refresh.
- **Server Info** — `reckon_db` / `reckon_gateway` versions and the integrity (HMAC) advertisement for a selected store.

**Classic** (stream-oriented reads)
- **Streams** — pick a store, read a single stream forward/backward with `From`/`Limit`.
- **Global** — the global ordered event log with `Offset`/`Limit`.
- **By Type** — cross-stream read by event type.
- **By Tags** — cross-stream read by tags with match-any / match-all.
- **By Metadata** — cross-stream read by a metadata key/value.

**DCB** (Dynamic Consistency Boundary — see [dcb-ccc.md](dcb-ccc.md))
- **Log** — paginated DCB event log.
- **Tags** — DCB tag index with per-tag counts.
- **Event Types** — DCB event-type index with counts.
- **Context** — run a tag-filter query and inspect the matching context + `max_seq`.

**CCC** (compound payload indexes — see [dcb-ccc.md](dcb-ccc.md))
- **Payload Query** — query by a single declared payload field. The key is a dropdown populated from `GET /dcb/payload-indexes`; if the store declares none (or the backend is older than reckon-gater 3.7), it falls back to a free-text key with an explanatory note.
- **Hash Query** — query by a declared payload-hash combination. The UI renders one labelled input per field name in the combination; the operator never types or sees the SHA-256 hash (it stays a server-side addressing detail).

The Classic/by-* and CCC views need the matching secondary or payload index declared on the store, otherwise the read returns nothing. See [env-contract.md](env-contract.md) (`RECKON_GATEWAY_STORE_INDEXES`) and [dcb-ccc.md](dcb-ccc.md).

## Server-Sent Events

`GET /v1/admin/events` is a `text/event-stream` the admin UI subscribes to for live status. You can consume it from any SSE client (or `curl -N`).

On connect the server subscribes to the catalogue, pushes an initial `status`, then pushes a fresh `status` every 10 seconds and on every catalogue change. A `: keepalive` comment frame is sent on each tick to hold the connection open through proxies.

Named events:

```
event: status
data: {"catalogue_size":3,"clusters":[{"cluster_id":"parksim","members":["..."],"store_count":2,"status":"up","last_refresh":1782820800000}],"timestamp_ms":1782820800000}

event: store_announced
data: {"store_id":"my_store","cluster_id":"local","node":"reckon_gateway@...","mode":"single"}

event: store_retired
data: {"store_id":"my_store","cluster_id":"local"}
```

Example:

```bash
curl -N http://localhost:8080/v1/admin/events
```

## Branding assets

`priv/static/admin/` also ships the ReckonDB brand mark (`reckondb-mark.svg`) and favicons (`favicon-16x16.png`, `favicon-32x32.png`, `favicon.ico`, `apple-touch-icon.png`) sourced from reckon-artwork.
