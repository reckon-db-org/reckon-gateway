# ReckonDB gRPC Gateway

gRPC gateway for [ReckonDB](https://codeberg.org/reckon-db-org/reckon-db) — exposes the BEAM-native event store to polyglot clients over gRPC.

## Overview

ReckonDB is a distributed event store built on Khepri/Ra (Raft consensus). It runs natively on the BEAM VM. This gateway wraps the full ReckonDB API in gRPC services, enabling Go, .NET, Rust, Python, and any gRPC-capable language to use ReckonDB as their event store.

## Services

| Service | Proto File | Description |
|---------|-----------|-------------|
| **StreamService** | `reckon_streams.proto` | Append, read, list, delete event streams |
| **SubscriptionService** | `reckon_subscriptions.proto` | Persistent subscriptions with server-streaming |
| **SnapshotService** | `reckon_snapshots.proto` | Aggregate state snapshots |
| **HealthService** | `reckon_health.proto` | Health checks, cluster diagnostics, memory pressure |
| **TemporalService** | `reckon_temporal.proto` | Time-based event queries |
| **CausationService** | `reckon_causation.proto` | Event lineage and correlation tracking |
| **SchemaService** | `reckon_schema.proto` | Event schema registration and upcasting |
| **AdminService** | `reckon_admin.proto` | Store inspection, scavenging, stream links |

## Quick Start

### Docker

```bash
docker build -t reckon-gateway .
docker run -p 50051:50051 -v reckon-data:/app/data reckon-gateway
```

### From Source

```bash
# Generate gRPC stubs from proto files
rebar3 grpc gen

# Compile
rebar3 compile

# Run in shell
rebar3 shell
```

### Client (Go example)

```go
conn, _ := grpc.Dial("localhost:50051", grpc.WithInsecure())
client := gatewayv1.NewStreamServiceClient(conn)

// Append events
resp, _ := client.AppendEvents(ctx, &gatewayv1.AppendEventsRequest{
    StoreId:         "default_store",
    StreamId:        "user-123",
    ExpectedVersion: -1, // NO_STREAM
    Events: []*gatewayv1.ProposedEvent{{
        EventType: "user_registered_v1",
        Data:      []byte(`{"name":"Alice","email":"alice@example.com"}`),
    }},
})
```

## Proto Files

Proto definitions live in `proto/` and are the source of truth for all client SDKs. Generate client code for your language:

```bash
# Go
protoc --go_out=. --go-grpc_out=. proto/*.proto

# .NET
dotnet-grpc refresh

# Python
python -m grpc_tools.protoc -Iproto --python_out=. --grpc_python_out=. proto/*.proto
```

## Architecture

```
Client (Go, .NET, Rust, Python, ...)
    │ gRPC (HTTP/2)
    ▼
┌─────────────────────────┐
│  reckon-gateway         │  ← This package
│  (grpcbox server)       │
│                         │
│  Converts proto ↔ gater │
└─────────────────────────┘
    │ Erlang function calls
    ▼
┌─────────────────────────┐
│  reckon-gater           │  ← Gateway API + worker registry
│  (esdb_gater_api)       │
└─────────────────────────┘
    │ pg process groups
    ▼
┌─────────────────────────┐
│  reckon-db              │  ← Event store (Khepri/Ra)
│  (Raft consensus)       │
└─────────────────────────┘
```

## Configuration

See `config/sys.config` for all options. Key settings:

| Setting | Default | Description |
|---------|---------|-------------|
| `listen_port` | `50051` | gRPC server port |
| `listen_ip` | `{0,0,0,0}` | Bind address |
| `stores` | `[{default_store, [...]}]` | ReckonDB store configuration |

## Expected Version Constants

For optimistic concurrency control in `AppendEvents`:

| Constant | Value | Meaning |
|----------|-------|---------|
| `NO_STREAM` | `-1` | Stream must not exist (first write) |
| `ANY_VERSION` | `-2` | No version check |
| `STREAM_EXISTS` | `-4` | Stream must already exist |
| `>= 0` | exact | Exact version match |

## License

Apache-2.0
