# `clusters.eterm` reference

The file that drives catalogue mode. Lists every remote ReckonDB cluster the gateway should federate.

## Schema

```erlang
[
    #{cluster_id => atom(),          %% unique within this gateway
      members    => [node()],        %% explicit list of every node in the cluster
      cookie     => binary(),        %% Erlang dist cookie for this cluster
      api_module => atom()           %% optional, defaults to reckon_gater_api
     }
    %% , one map per cluster
].
```

## Example

```erlang
[
    #{cluster_id => parksim,
      members    => ['parksim_entry2exit@192.168.1.10',
                     'parksim_lot@192.168.1.11',
                     'parksim_pricing@192.168.1.12',
                     'parksim_simulator@192.168.1.13'],
      cookie     => <<"<parksim-cluster-cookie>">>},

    #{cluster_id => analytics,
      members    => ['reckon_analytics@10.0.4.5',
                     'reckon_analytics@10.0.4.6'],
      cookie     => <<"<analytics-cluster-cookie>">>}
].
```

## Rules

- **`members` is the full member list.** The connector dials every member directly , there is no reliance on the target cluster having a healthy internal mesh, and a degraded peer doesn't take the gateway down.
- **Per-cluster cookies.** Each `cluster_id` carries its own cookie; the gateway switches the BEAM's cookie via `erlang:set_cookie/2` before each dial. The gateway's own `RELEASE_COOKIE` is unused for federation.
- **`api_module` is optional.** Defaults to `reckon_gater_api`. Older clusters may still run `esdb_gater_api` (pre-rename) , set the override per-cluster during migrations.
- **Duplicate `cluster_id` is an error.** Validation rejects the file with `{duplicate_cluster_id, Id}`.

## Operational hygiene

> **Cookies are secrets. Do not commit `clusters.eterm` to gitops.**

- Bind-mount the file read-only into the container at `/etc/reckon-gateway/clusters.eterm` (the Dockerfile default).
- File mode `0600` on the host; owner the user the gateway runs as.
- Rotate cookies via the same flow as any other shared secret , update the file, restart the gateway.
- The gateway redacts cookies from log lines and error tuples (`reckon_gateway_config:redact/1`). Don't add your own log lines that surface them.

## Validation behaviour

`reckon_gateway_config:load_clusters/0` is forgiving on absence (no file -> empty catalogue, every data RPC for an unknown `store_id` returns `store_unknown`) but strict on malformed content. Invalid entries produce explicit errors:

| Error | Cause |
|---|---|
| `{invalid_format, Path, Got}` | File didn't parse as a single Erlang term that's a list |
| `{read_failed, Path, Reason}` | `file:consult/1` returned an error (permissions, IO) |
| `{duplicate_cluster_id, Id}` | Two entries with the same `cluster_id` |
| `{invalid_cluster_spec, Spec}` | Missing/wrong-typed required keys (`members` empty, `cookie` not a binary, etc.) |

The gateway fails to start on the latter three. Empty + missing-file is treated as "no clusters configured" , a valid state.

## Hidden-node mode

Catalogue mode benefits from running the gateway with `RECKON_GATEWAY_DIST_HIDDEN_FLAG=-hidden`. Without it, every cluster's nodes learn the names of every OTHER cluster's nodes (via the gateway's `nodes/0`) and try to dist-handshake them; those handshakes bounce on cookie mismatch, generating log noise and wasted attempts. With `-hidden`, the gateway is invisible to each cluster's pg scope and `nodes/0`, so each cluster stays cleanly isolated. See [env-contract.md#hidden-node-flag](env-contract.md#hidden-node-flag).

## Reload semantics

The connectors re-read `clusters.eterm` every `refresh_interval_ms` (default 30s). Adding a cluster: edit + save , the next refresh picks it up. Removing a cluster: edit + save , the connector drops the entry on next refresh and the catalogue removes its stores. **You do not need to restart the gateway** to pick up clusters.eterm changes.
