# Environment contract

Every operational setting is env-driven. The release's `sys.config.src` interpolates the values at boot; un-substituted `${VAR}` placeholders fall through to OS env via `reckon_gateway_config:env_string/3`. App env wins over OS env so test harnesses can override without touching the shell.

## Always (every mode)

| Var | Default | Meaning |
|---|---|---|
| `RECKON_GATEWAY_PORT` | `50051` | gRPC listen port. Bound to `0.0.0.0`. |
| `NODE_NAME` | `reckon_gateway@127.0.0.1` | Erlang long node name. Must be unique per host in a cluster. |
| `RELEASE_COOKIE` | `reckon_gateway_unused_default` | BEAM dist cookie. Unused for `clusters.eterm` peers (per-peer cookies override). **Must match across cluster-mode embedded-store peers.** |
| `RECKON_GATEWAY_DIST_HIDDEN_FLAG` | `""` (visible) | Literal BEAM vm.arg substitution. Set to `-hidden` to start the gateway as a hidden dist node. See [Hidden-node flag](#hidden-node-flag) below. |

## Hidden-node flag

`-hidden` is a BEAM startup flag (`erl -hidden`). A hidden node connects to peers individually, is non-transitive, and does NOT appear in peers' `nodes/0` lists. OTP's `pg` module subscribes via `net_kernel:monitor_nodes(true)` which filters hidden nodes, so each cluster's `reckon_gater` pg scope stays isolated from siblings when bridged through a hidden gateway.

**Set `RECKON_GATEWAY_DIST_HIDDEN_FLAG=-hidden` when:**

- Running pure **catalogue mode** (federating cookie-disjoint clusters). Without it, cluster A's nodes see cluster B's nodes via the gateway's `nodes/0`, attempt cross-cluster dist handshakes, and bounce on cookie mismatch , log noise + churn.
- Running **embedded single-node** mode. No peers to confuse; hidden is neutral but consistent with catalogue.
- Running **hybrid mode** with `STORE_MODE=single`. Catalogue side wants hidden; embedded single side doesn't care.

**Leave empty (default) when:**

- Running **embedded cluster mode** (`STORE_MODE=cluster`, 3+ containers forming a Ra quorum). Gateway containers are peers of each other; reckon_gater pg + Ra need mutual visibility. `-hidden` breaks this.
- Running **hybrid mode** with `STORE_MODE=cluster`. Same constraint.

There is **no smart default**; the operator picks. Catalogue and embedded-cluster have opposite needs, and an inferred default would silently break one of them. Be explicit.

## Catalogue mode

| Var | Default | Meaning |
|---|---|---|
| `RECKON_GATEWAY_CLUSTERS_PATH` | `/etc/reckon-gateway/clusters.eterm` | Absolute path to operator-curated `clusters.eterm`. Holds remote-cluster specs + cookies. When unset or pointing at a missing file, the catalogue boots with zero remote clusters and every data RPC for a remote-only `store_id` returns `store_unknown`. |

The clusters file is a single Erlang term file containing a list of maps:

```erlang
[
    #{cluster_id => parksim,
      members    => ['parksim_entry2exit@192.168.1.10',
                     'parksim_lot@192.168.1.11',
                     'parksim_pricing@192.168.1.12'],
      cookie     => <<"tKcK...">>}
    %% , additional clusters
].
```

See [clusters-eterm.md](clusters-eterm.md) for the full schema. **Cookies are secrets** , the file MUST live outside any gitops repo, chmod 0600.

## Embedded mode (opt-in, 0.6+)

Activated when `RECKON_GATEWAY_STORE_ENABLED=true` (also accepts `1`, `yes`). Anything else , including unset and the unsubstituted `${...}` placeholder , keeps catalogue-only behaviour.

| Var | Default | Meaning |
|---|---|---|
| `RECKON_GATEWAY_STORE_ENABLED` | `false` | Master switch. |
| `RECKON_GATEWAY_STORE_ID` | (required if enabled) | Atom name of the local store. Becomes its identity in `reckon_db_store_registry` and the catalogue. |
| `RECKON_GATEWAY_DATA_DIR` | `/data` | Persistent volume root for Khepri/Ra WAL + state. Container declares `VOLUME /data`. |
| `RECKON_GATEWAY_STORE_MODE` | `single` | `single` (standalone) or `cluster` (participates in Ra quorum). |
| `RECKON_GATEWAY_LOCAL_CLUSTER_ID` | `local` | Catalogue label for the local store. Lets clients see it alongside remote `clusters.eterm` entries. |

If `STORE_ENABLED=true` and either `STORE_ID` or `DATA_DIR` resolves empty, the gateway refuses to boot with `{embedded_store_misconfigured, missing_store_id}` (or `missing_data_dir`). Silent fallbacks to a no-identity store would be worse than an explicit crash.

## Cluster-mode shared (when `STORE_MODE=cluster`)

| Var | Default | Meaning |
|---|---|---|
| `RECKON_DB_CLUSTER_SECRET` | (required) | Shared secret consumed by `reckon_db_discovery`. Peers with matching secret form Ra quorum; mismatches reject. |
| `RECKON_DB_MULTICAST_ADDR` | `239.255.0.1` | Multicast group override. Useful when running multiple isolated clusters on one L2 segment. |

`RECKON_DB_CLUSTER_SECRET` is **not** declared via `ENV` in the Dockerfile (per Docker's `SecretsUsedInArgOrEnv` lint, baking the name into image metadata is bad practice). Supply at runtime via compose `environment:`, k8s `secretKeyRef`, systemd `EnvironmentFile=`, or `--env-file`. Single-mode deployments don't need it.

## Precedence

```
application:get_env(reckon_gateway, K)   ; wins if set + non-empty + not a ${...} placeholder
  v fallback
os:getenv("RECKON_GATEWAY_K")            ; wins if set + non-empty + not a ${...} placeholder
  v fallback
hard-coded default
```

This lets `sys.config.src` (which receives substituted values from rebar3 / `RUNTIME_CONFIG`) be authoritative in production, while tests can override via `application:set_env/3` without touching the OS environment.

## Cheatsheet

```bash
# Catalogue-only (federates remote clusters; gateway holds no data):
RECKON_GATEWAY_PORT=50051
RECKON_GATEWAY_CLUSTERS_PATH=/etc/reckon-gateway/clusters.eterm
RECKON_GATEWAY_DIST_HIDDEN_FLAG=-hidden

# Embedded single-node (one container = one store):
RECKON_GATEWAY_PORT=50051
RECKON_GATEWAY_STORE_ENABLED=true
RECKON_GATEWAY_STORE_ID=my_store
RECKON_GATEWAY_DATA_DIR=/data
RECKON_GATEWAY_STORE_MODE=single
RECKON_GATEWAY_LOCAL_CLUSTER_ID=my_local
RECKON_GATEWAY_DIST_HIDDEN_FLAG=-hidden

# Embedded cluster (3+ containers form Ra quorum):
# ... same as single, plus:
RECKON_GATEWAY_STORE_MODE=cluster
RECKON_DB_CLUSTER_SECRET=<shared-secret>
RELEASE_COOKIE=<shared-cookie>
RECKON_GATEWAY_DIST_HIDDEN_FLAG=                # MUST be empty for cluster peers
```
