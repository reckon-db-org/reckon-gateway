# Embedded mode

`reckon-gateway` 0.6+ can boot a local `reckon_db` store in its own BEAM. Activate with `RECKON_GATEWAY_STORE_ENABLED=true`.

Use this mode when:

- You want a single OCI image that exposes ReckonDB over gRPC without standing up a separate BEAM cluster
- You're running on a single host (compose, k8s `StatefulSet` of 1, edge device)
- You're running a small Ra/Raft quorum (3-5 containers, k8s `StatefulSet`)

If you need to **federate already-running** ReckonDB clusters under one gRPC endpoint, see [catalogue mode](architecture.md#layers) instead , no local store needed.

## Single-node

The minimal embedded deployment. One container, one Khepri store, no clustering.

**Compose:**

```yaml
services:
  reckon-gateway:
    image: ghcr.io/reckon-db-org/reckon-gateway:0.17.0
    ports: ["50051:50051", "8080:8080"]
    volumes:
      - reckon-data:/data
    environment:
      RECKON_GATEWAY_STORE_ENABLED: "true"
      RECKON_GATEWAY_STORE_ID:      "my_store"
      RECKON_GATEWAY_LOCAL_CLUSTER_ID: "local"
      RECKON_GATEWAY_STORE_MODE:    "single"
      RECKON_GATEWAY_DIST_HIDDEN_FLAG: "-hidden"

volumes:
  reckon-data:
```

The store boots at startup, registers itself with `reckon_db_store_registry`, and the local connector publishes it into the gateway catalogue within 5 seconds. From then on, any gRPC call with `store_id = "my_store"` hits the local store.

> **Tuning the hosted store.** The env vars above cover identity and placement. To set pool sizes, operation timeout, tamper-resistance (HMAC), or **CCC payload indexes** (`{payload,_}` / `{payload_hash,_}`), mount a `store.eterm` at `RECKON_GATEWAY_STORE_PATH` — see [store-config.md](store-config.md). Those advanced fields can only be declared via the file.

## Cluster (Ra/Raft quorum)

Multiple containers form a Khepri/Ra cluster. **One store per container** , N tenants means N containers.

### Discovery (LAN)

`reckon_db` uses UDP multicast for peer discovery on a LAN. All peers must share `RECKON_DB_CLUSTER_SECRET` and `RELEASE_COOKIE`.

> **Leave `RECKON_GATEWAY_DIST_HIDDEN_FLAG` empty in cluster mode.** Gateway containers are dist peers of each other; reckon_gater's `pg` scope and Ra/Raft need mutual visibility. Setting `-hidden` breaks pg sync across the quorum. See [env-contract.md#hidden-node-flag](env-contract.md#hidden-node-flag).

```yaml
services:
  gw-1:
    image: ghcr.io/reckon-db-org/reckon-gateway:0.6.2
    network_mode: host                                # multicast needs host net
    volumes: ["data-1:/data"]
    environment:
      RECKON_GATEWAY_STORE_ENABLED: "true"
      RECKON_GATEWAY_STORE_ID:      "shared_store"
      RECKON_GATEWAY_STORE_MODE:    "cluster"
      RECKON_GATEWAY_LOCAL_CLUSTER_ID: "ra_quorum"
      NODE_NAME:                    "gw1@${HOST_IP}"
      RELEASE_COOKIE:               "${SHARED_COOKIE}"
      RECKON_DB_CLUSTER_SECRET:     "${SHARED_SECRET}"

  # gw-2, gw-3 same shape with NODE_NAME=gw2@..., gw3@...

volumes: { data-1: {}, data-2: {}, data-3: {} }
```

### Discovery (Kubernetes)

`reckon_db_discovery` falls back to DNS-based peer resolution when multicast isn't viable. Run as a headless `StatefulSet`; pods discover each other via the cluster's DNS records. See [reckon-db's discovery guide](https://codeberg.org/reckon-db-org/reckon-db) for the DNS query shape; the gateway only needs to pass `STORE_MODE=cluster` through to it.

## Persistence

`/data` is a `VOLUME` , the operator MUST mount a durable volume there. Khepri/Ra writes WAL segments + snapshots; eat the disk too quickly without a snapshot policy and Ra will refuse to truncate. See `reckon_db`'s snapshot configuration for retention tuning.

## Mode migration

**Single -> cluster mid-life isn't supported.** The on-disk layout differs (Ra membership state). Deploy at the intended mode; don't flip an already-running single-node store to cluster. To migrate: stand up a fresh cluster, replay events from the old single-node store via a backfill tool, then cut over.

## What happens at boot

1. `reckon_gateway_config:embedded_store_spec/0` reads env, validates, returns `#{store_id, data_dir, mode, cluster_id}` (or `disabled`).
2. `reckon_gateway_store_starter` (transient worker) builds a `#store_config{}` and calls `reckon_db_sup:start_store/1`. Returns `ignore`.
3. `reckon_db` mounts Khepri, joins Ra quorum if `mode=cluster`, registers in `reckon_db_store_registry`.
4. `reckon_gateway_local_connector` polls the registry every 5s and publishes entries into `reckon_gateway_catalogue` under the operator-set `LOCAL_CLUSTER_ID`.
5. gRPC services route by `store_id`; the local store resolves to `members = [node()]`, so dispatch stays on-BEAM.

## Verifying

```bash
# Connect to the running container's shell:
podman exec -it reckon-gw /app/bin/reckon_gateway remote_console
```

```erlang
%% In the remote console:
> reckon_db_store_registry:list_stores().
{ok, [#{store_id => my_store, mode => single, node => 'gw@host', ...}]}

> reckon_gateway_catalogue:list().
[#{cluster_id => local, stores => [my_store], ...}]
```

Both calls returning the store means the boot chain succeeded.
