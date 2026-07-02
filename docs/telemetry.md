# Telemetry

reckon-gateway is instrumented with [`telemetry`](https://hexdocs.pm/telemetry),
the standard BEAM instrumentation library. The gateway is the polyglot ingress —
every store operation from an HTTP/JSON or gRPC client is routed through the
dispatch layer to a member of the owning cluster, and the fleet of federated
stores is tracked by the catalogue. These are the two things worth measuring,
and both are instrumented:

- **Dispatch** — request throughput, latency, and failure rate at the single
  choke point every store operation crosses.
- **Catalogue** — the federated fleet: which stores are announced or retired.

Telemetry is in-process pub/sub; emitting an event with no attached handler
costs one ETS lookup, so instrumentation is free until you opt in. Metrics never
leave the node on their own and never cross the gRPC wire — you attach a handler
(logger, Prometheus, OpenTelemetry) to export them.

## How it works

An event is a stable list of atoms, e.g. `[reckon_gateway, dispatch, stop]`.
When the operation happens the gateway calls:

```erlang
telemetry:execute(Event, Measurements, Metadata).
```

- **Measurements** — numbers (durations, timestamps) for counters/histograms.
- **Metadata** — context (`store_id`, `op`, `reason`) for labels/filtering.

Handlers run synchronously in the emitting process, so keep them cheap.

## Quick start

The gateway attaches the built-in logger handler automatically at boot when the
`telemetry_handlers` environment key includes `logger` (the default). To attach
your own handler:

```erlang
reckon_gateway_telemetry:attach(my_metrics, fun my_app:handle/4, #{}).
```

Example — a dispatch error-rate counter:

```erlang
handle([reckon_gateway, dispatch, error], _M, #{op := Op, reason := Reason}, _Cfg) ->
    my_counter:add({dispatch_error, Op, Reason}, 1),
    ok;
handle(_Event, _M, _Meta, _Cfg) ->
    ok.
```

## The facade

`reckon_gateway_telemetry` is the public entry point:

| Function | Purpose |
|---|---|
| `attach_default_handler/0` | Attach the built-in logger handler. |
| `detach_default_handler/0` | Remove it. |
| `attach/3` | Attach a custom `HandlerId, Fun, Config` across gateway events. |
| `detach/1` | Remove a handler by id. |
| `emit/3` | Emit an event. |
| `all_events/0` | The list of gateway event names, for `telemetry:attach_many`. |

## Configuration

At application start the gateway reads:

```erlang
{reckon_gateway, [
    {telemetry_handlers, [logger]}   %% default
]}.
```

- `[logger]` — attach the built-in logger handler (default).
- `[]` — attach nothing; events are emitted silently until you attach your own.
- Add exporters alongside `logger` by attaching them from your own supervision
  tree with `reckon_gateway_telemetry:attach/3`.

## Metrics exporters

- **Prometheus** — [`telemetry_metrics_prometheus`](https://hexdocs.pm/telemetry_metrics_prometheus)
  to define counters/histograms and expose a `/metrics` scrape endpoint.
- **OpenTelemetry** — [`opentelemetry`](https://hexdocs.pm/opentelemetry) + a
  telemetry bridge, exported over OTLP.

## Event catalogue

The definitive list with inline measurement/metadata docs lives in
`include/reckon_gateway_telemetry.hrl`. Durations are in microseconds.

### Dispatch (the request path)

Emitted around every `reckon_gateway_dispatch:call/2,3` — i.e. every store
operation that crosses from the gateway to a cluster member. `op` is the
reckon_gater_api function name (`append_events`, `get_streams`, …). A success is
bracketed by `start` + `stop`; a failure by `start` + `error`.

| Event | Measurements | Metadata |
|---|---|---|
| `[reckon_gateway, dispatch, start]` | `system_time` | `store_id, op` |
| `[reckon_gateway, dispatch, stop]` | `duration` | `store_id, op` |
| `[reckon_gateway, dispatch, error]` | `duration` | `store_id, op, reason` |

`reason` is a low-cardinality atom: `store_unknown` (no catalogue entry),
`cluster_unavailable` (no healthy member), `rpc_failed` (the dist call to the
member failed), or `other`.

### Catalogue (the federated fleet)

Emitted when a store first appears in or leaves the merged catalogue. Mirrors
the `store_announced` / `store_retired` Server-Sent Events stream the admin UI
consumes (see [Admin UI](admin-ui.md)), but fires independently of whether any
UI is connected.

| Event | Measurements | Metadata |
|---|---|---|
| `[reckon_gateway, store, announced]` | `system_time` | `store_id, cluster_id` |
| `[reckon_gateway, store, retired]` | `system_time` | `store_id, cluster_id` |

## What to watch

- **Throughput / latency** — count + `duration` histogram of `dispatch.stop`,
  grouped by `op` and `store_id`.
- **Error rate** — `dispatch.error` rate by `reason`. A spike in
  `cluster_unavailable` or `rpc_failed` points at a struggling or partitioned
  backend cluster; `store_unknown` points at a client addressing a store the
  gateway doesn't know.
- **Fleet churn** — `store.announced` / `store.retired` volume.

## Backend telemetry

The gateway holds no data of its own (in catalogue mode); the store operations
it dispatches are executed on ReckonDB cluster members, which emit their own,
richer telemetry — stream writes/reads, subscriptions, snapshots, quorum and
leadership events. See the ReckonDB and reckon-gater telemetry guides for those
catalogues. Gateway telemetry measures the *ingress*; ReckonDB telemetry
measures the *engine*.
