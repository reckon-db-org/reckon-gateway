# Go quick start

Connect to a running `reckon-gateway` and round-trip an event in under 5 minutes.

## Prerequisites

- Go 1.22+
- A running gateway (any mode) reachable at `localhost:50051`
  - Single-node embedded for the simplest setup: see [embedded-mode.md#single-node](../embedded-mode.md#single-node).

## Get the protos

Proto definitions live in [reckon-proto](https://github.com/reckon-db-org/reckon-proto). Generate Go stubs:

```bash
git clone https://github.com/reckon-db-org/reckon-proto.git
cd reckon-proto

mkdir -p ../gen/go
protoc \
  --go_out=../gen/go --go_opt=paths=source_relative \
  --go-grpc_out=../gen/go --go-grpc_opt=paths=source_relative \
  -I proto proto/*.proto
```

If you'd rather not run `protoc` yourself, use the prebuilt Go client at [reckon-go](https://github.com/reckon-db-org/reckon-go).

## Minimal example

```go
package main

import (
    "context"
    "encoding/json"
    "fmt"
    "log"
    "time"

    streampb "your.module/gen/go/reckon/gateway/v1"

    "google.golang.org/grpc"
    "google.golang.org/grpc/credentials/insecure"
)

func main() {
    conn, err := grpc.NewClient(
        "localhost:50051",
        grpc.WithTransportCredentials(insecure.NewCredentials()),
    )
    if err != nil {
        log.Fatalf("dial: %v", err)
    }
    defer conn.Close()

    client := streampb.NewStreamServiceClient(conn)
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    // Append a single event.
    payload, _ := json.Marshal(map[string]string{"name": "Alice"})
    appendResp, err := client.AppendEvents(ctx, &streampb.AppendEventsRequest{
        StoreId:         "my_store",
        StreamId:        "user-7c4b9f1e2a8d4c3b9f7e5d1a2b3c4d5e",
        ExpectedVersion: -1, // NO_STREAM, must be a new stream
        Events: []*streampb.ProposedEvent{{
            EventType: "user_registered_v1",
            Data:      payload,
        }},
    })
    if err != nil {
        log.Fatalf("append: %v", err)
    }
    fmt.Printf("appended at version %d\n", appendResp.GetNewVersion())

    // Read it back.
    readResp, err := client.ReadEvents(ctx, &streampb.ReadEventsRequest{
        StoreId:   "my_store",
        StreamId:  "user-7c4b9f1e2a8d4c3b9f7e5d1a2b3c4d5e",
        FromVersion: 0,
        Count:       100,
        Direction:   streampb.ReadDirection_FORWARD,
    })
    if err != nil {
        log.Fatalf("read: %v", err)
    }
    for _, e := range readResp.GetEvents() {
        fmt.Printf("v%d  %s  %s\n", e.GetVersion(), e.GetEventType(), string(e.GetData()))
    }
}
```

## Stream IDs

Stream IDs follow `{prefix}-{uuid_without_dashes}` (regex `^[a-z]{1,32}-[a-f0-9]{32}$`). The validator lives in `reckon_gater` and is enforced at append time , a malformed ID returns `INVALID_ARGUMENT`. Generate UUIDv7s (time-sortable) for natural ordering.

```go
import "github.com/gofrs/uuid/v5"

func streamID(prefix string) string {
    id, _ := uuid.NewV7()
    return prefix + "-" + strings.ReplaceAll(id.String(), "-", "")
}
```

## Expected version constants

| Constant | Value | Meaning |
|---|---|---|
| `NO_STREAM` | `-1` | Stream must not exist (first write) |
| `ANY_VERSION` | `-2` | No version check , appends regardless |
| `STREAM_EXISTS` | `-4` | Stream must already exist |
| `>= 0` | exact | Strict version match (optimistic concurrency) |

## Subscriptions (server-streaming)

```go
subClient := subpb.NewSubscriptionServiceClient(conn)
stream, _ := subClient.SubscribeToStream(ctx, &subpb.SubscribeRequest{
    StoreId:  "my_store",
    StreamId: "user-7c4b9f...",
    FromVersion: 0,
})
for {
    ev, err := stream.Recv()
    if err != nil { break }
    fmt.Printf("got v%d %s\n", ev.GetVersion(), ev.GetEventType())
}
```

For a full client with subscription lifecycle, snapshots, and reconnection, see [reckon-go](https://github.com/reckon-db-org/reckon-go).
