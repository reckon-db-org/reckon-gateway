# reckon-gateway documentation

Operator + developer reference for the [reckon-gateway](../README.md) gRPC + HTTP ingress. Each page is self-contained; read by audience or read the suggested orders below.

## Pages

| Doc | What it covers |
|---|---|
| [Architecture](architecture.md) | Layer breakdown, catalogue + connector roles, boot sequence, hidden-node bridging, why catalogue/embedded are independent flags. |
| [Environment contract](env-contract.md) | Every env var with semantics and precedence (app env > OS env > default). Includes `RECKON_GATEWAY_HTTP_PORT`, `RECKON_GATEWAY_STORE_INDEXES`, and the **Hidden-node flag** section. |
| [HTTP/JSON API reference](http-api.md) | The REST surface on port `8080`: health/discovery, streams, indexed reads, DCB/CCC, error + event JSON shapes, expected-version values. |
| [Admin UI + SSE](admin-ui.md) | The browser admin UI at `/admin`, its views, and the `/v1/admin/events` Server-Sent Events stream. |
| [DCB + CCC queries](dcb-ccc.md) | Dynamic Consistency Boundary (tag-filter context + conditional append) and CCC payload-indexed reads, over gRPC + HTTP. |
| [Embedded mode](embedded-mode.md) | Operator guide for `STORE_ENABLED=true` deployments: single-node + Ra cluster setups, persistence, verification via `remote_console`, mode-migration warnings. |
| [`store.eterm` reference](store-config.md) | Full `#store_config{}` for the hosted store: pools, timeout, integrity/HMAC, and CCC `{payload,_}` / `{payload_hash,_}` indexes; precedence over env, validation, secret hygiene. |
| [`clusters.eterm` reference](clusters-eterm.md) | Federation config file: schema, validation rules, secret hygiene, reload semantics, hidden-node recommendation. |
| [Building from source](building.md) | rebar3 + Rust toolchain prerequisites, gRPC stub generation, test commands, gotchas (em-dash in sys.config.src, Rust pin). |
| [Go quick start](examples/go-quickstart.md) | Connect, append, read, subscribe end-to-end in one page. Stream-id format + expected-version constants. |

## Suggested reading orders

**I want to operate it (catalogue, embedded, or hybrid):**

1. [Architecture](architecture.md) , one page to know how it dispatches
2. [Environment contract](env-contract.md) , env vars you'll set
3. Pick the deployment doc that matches you: [Embedded mode](embedded-mode.md) for `STORE_ENABLED=true` (and [`store.eterm` reference](store-config.md) to tune the hosted store / declare CCC indexes), or [`clusters.eterm` reference](clusters-eterm.md) for federation

**I want to build a client against it:**

1. Over HTTP/JSON (curl, browser, scripts): [HTTP/JSON API reference](http-api.md) , the full REST surface
2. Over gRPC: [Go quick start](examples/go-quickstart.md) , then [proto definitions in reckon-proto](https://codeberg.org/reckon-db-org/reckon-proto)
3. Advanced reads/writes: [DCB + CCC queries](dcb-ccc.md)

**I want to poke at a running gateway in a browser:**

1. [Admin UI + SSE](admin-ui.md) , open `http://<host>:8080/admin`

**I want to hack on the gateway itself:**

1. [Building from source](building.md)
2. [Architecture](architecture.md) , the implementation map

## Assets

- [`assets/logo.svg`](assets/logo.svg) , brand mark (sphere + Eye of Horus / Seshat) reused from reckon-portal
- [`assets/architecture.svg`](assets/architecture.svg) , three-mode overview diagram referenced from the top-level README

## Plans + design history

Background docs (mostly historical) live in [`../plans/`](../plans/):

- `DESIGN_RECKON_GATEWAY_CATALOGUE.md` , the 0.5 catalogue refactor design
- `DESIGN_RECKON_GATEWAY_HYBRID_MODE.md` , the 0.6 hybrid-mode design (current)
- `RESEARCH_CATALOGUE_SPIKES.md` , spikes that validated the catalogue model
- `DESIGN_RECKON_GATEWAY_PROXY_MODE.md` , superseded; kept for archaeology
