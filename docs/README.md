# reckon-gateway documentation

Operator + developer reference for the [reckon-gateway](../README.md) gRPC ingress. Each page is self-contained; read by audience or read the suggested orders below.

## Pages

| Doc | What it covers |
|---|---|
| [Architecture](architecture.md) | Layer breakdown, catalogue + connector roles, boot sequence, hidden-node bridging, why catalogue/embedded are independent flags. |
| [Environment contract](env-contract.md) | Every env var with semantics and precedence (app env > OS env > default). Includes the **Hidden-node flag** section governing `RECKON_GATEWAY_DIST_HIDDEN_FLAG`. |
| [Embedded mode](embedded-mode.md) | Operator guide for `STORE_ENABLED=true` deployments: single-node + Ra cluster setups, persistence, verification via `remote_console`, mode-migration warnings. |
| [`clusters.eterm` reference](clusters-eterm.md) | Federation config file: schema, validation rules, secret hygiene, reload semantics, hidden-node recommendation. |
| [Building from source](building.md) | rebar3 + Rust toolchain prerequisites, gRPC stub generation, test commands, gotchas (em-dash in sys.config.src, Rust pin). |
| [Go quick start](examples/go-quickstart.md) | Connect, append, read, subscribe end-to-end in one page. Stream-id format + expected-version constants. |

## Suggested reading orders

**I want to operate it (catalogue, embedded, or hybrid):**

1. [Architecture](architecture.md) , one page to know how it dispatches
2. [Environment contract](env-contract.md) , env vars you'll set
3. Pick the deployment doc that matches you: [Embedded mode](embedded-mode.md) for `STORE_ENABLED=true`, or [`clusters.eterm` reference](clusters-eterm.md) for federation

**I want to build a client against it:**

1. [Go quick start](examples/go-quickstart.md) , covers the wire shape
2. [proto definitions in reckon-proto](https://codeberg.org/reckon-db-org/reckon-proto)

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
