# `store.eterm` reference — embedded store configuration

When the gateway hosts a reckon-db store (`RECKON_GATEWAY_STORE_ENABLED=true`), the simple knobs come from env vars (`STORE_ID`, `DATA_DIR`, `STORE_MODE`, `LOCAL_CLUSTER_ID`, `STORE_INDEXES` — see [env-contract.md](env-contract.md)). The **full** reckon-db `#store_config{}` surface — performance pools, operation timeout, an arbitrary `options` map, tamper-resistance, and **CCC payload indexes** — is declared in an optional `store.eterm` file.

The file path is `RECKON_GATEWAY_STORE_PATH` (default `/etc/reckon-gateway/store.eterm`). Absent file → env-only config, exactly as before. The file is read **once at boot**: store config (especially `indexes` and `integrity`) is a genesis property — declared at store creation, not changed live. To change index/integrity declarations, recreate the store.

## Why a file (not more env vars)

Two of the advanced fields don't encode cleanly as strings:

- `{payload_hash, [<<"flight_id">>, <<"seat_no">>]}` — an index is a *list* of payload keys, and a store can declare several.
- `integrity => #{enabled => true, key_source => {env_var, <<"RECKON_HMAC">>}}` — a structured key-source.

An Erlang term file expresses these as the real types reckon-db consumes, with no lossy string grammar in between.

## Precedence

For each field, the file wins when it sets it; otherwise the matching env var applies, then reckon-db's record default:

```
store.eterm field   (if present)
  ↓ falls back to
RECKON_GATEWAY_* env (for store_id / data_dir / mode / cluster_id / indexes)
  ↓ falls back to
#store_config{} record default (reckon-db)
```

So you can keep `STORE_ID` / `DATA_DIR` in container env and declare only the advanced surface in the file, or move everything into the file. Both work.

## Schema

A single Erlang map term. Every key is optional (missing keys fall back per the precedence above), but `store_id` and `data_dir` must resolve from *somewhere* (file or env) or the gateway refuses to boot.

```erlang
%% /etc/reckon-gateway/store.eterm
#{
    %% Identity + placement (override env if set here)
    store_id   => my_store,      % atom
    data_dir   => "/data",        % string (the Khepri/Ra root)
    mode       => single,         % single | cluster
    cluster_id => local,          % atom; catalogue label for the local store

    %% Performance (override reckon-db record defaults)
    timeout           => 5000,    % pos_integer, ms — default operation timeout
    writer_pool_size  => 4,       % pos_integer
    reader_pool_size  => 4,       % pos_integer
    gateway_pool_size => 1,       % pos_integer

    %% Arbitrary passthrough options for reckon-db
    options => #{},               % map

    %% Declared secondary + payload indexes (genesis-only; no backfill).
    %% Maintained transactionally with every append.
    indexes => [
        tags,                                       % index every tag
        event_type,                                 % index the event type
        {meta, <<"correlation_id">>},               % index a metadata key
        {payload, <<"account_id">>},                % CCC: a top-level JSON payload field
        {payload_hash, [<<"flight_id">>, <<"seat_no">>]}  % CCC: a composite payload hash
    ],

    %% Tamper-resistance (HMAC + hash chain). Default: disabled.
    integrity => #{
        enabled    => true,
        key_source => {env_var, <<"RECKON_HMAC">>}   % or {sealed_file, "/run/secrets/hmac"}
    }
}.
```

### Field validation

The gateway validates the file at boot and **crashes with `{embedded_store_misconfigured, {invalid_store_config_file, Path, Reason}}`** on any violation — there is no silent fallback to a half-configured store.

| Key | Accepted |
|---|---|
| `store_id` | atom |
| `data_dir` | string (charlist) |
| `mode` | `single` \| `cluster` |
| `cluster_id` | atom |
| `timeout`, `*_pool_size` | positive integer |
| `options` | map |
| `indexes` | list of `tags` \| `event_type` \| `{meta, binary()}` \| `{payload, binary()}` \| `{payload_hash, [binary()]}` |
| `integrity` | `disabled` \| `#{enabled := true, key_source := {env_var, binary()} \| {sealed_file, string()}}` |

## CCC payload indexes

`{payload, Key}` and `{payload_hash, [Keys]}` (reckon-db 5.3+) are what make the gateway's CCC read endpoints return data:

- `GET /v1/stores/:store/dcb/by-payload?key=account_id&value=...`
- `POST /v1/stores/:store/dcb/by-payload-hash`
- `GET /v1/stores/:store/dcb/payload-indexes` (lists exactly what you declared here)

Without a declaration the indexes don't exist and those reads return nothing. See [dcb-ccc.md](dcb-ccc.md) for the query side.

## Integrity (HMAC) secret hygiene

`store.eterm` holds only the *reference* to the HMAC key, never the key itself:

- `{env_var, <<"RECKON_HMAC">>}` — the key is supplied at runtime in that environment variable (compose `environment:`, k8s `secretKeyRef`, systemd `EnvironmentFile=`). Do **not** bake the value into the image.
- `{sealed_file, "/run/secrets/hmac"}` — the key is read from a mounted secret file.

The file is still operator config: keep it outside any gitops repo and `chmod 0600`, same hygiene as `clusters.eterm`.

## Minimal example (CCC experiment)

Env: `RECKON_GATEWAY_STORE_ENABLED=true`, `RECKON_GATEWAY_STORE_ID=lab`, `RECKON_GATEWAY_DATA_DIR=/data`.

```erlang
%% store.eterm — just enough to play with CCC
#{ indexes => [ {payload, <<"account_id">>},
                {payload_hash, [<<"flight_id">>, <<"seat_no">>]} ] }.
```

```bash
podman run -d -p 50051:50051 -p 8080:8080 \
  -v reckon-data:/data \
  -v ./store.eterm:/etc/reckon-gateway/store.eterm:ro \
  -e RECKON_GATEWAY_STORE_ENABLED=true \
  -e RECKON_GATEWAY_STORE_ID=lab \
  ghcr.io/reckon-db-org/reckon-gateway:0.17.0

curl -s localhost:8080/v1/stores/lab/dcb/payload-indexes
# => {"payload":["account_id"],"payload_hash":[["flight_id","seat_no"]]}
```
