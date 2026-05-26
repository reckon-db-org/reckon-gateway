# Building from source

You only need this if you're hacking on the gateway or building a custom image. Production deployments should pull from `ghcr.io/reckon-db-org/reckon-gateway`.

## Prerequisites

- Erlang/OTP 27 or 28
- rebar3
- Rust 1.90+ (required at build time , `reckon_db`'s NIFs compile to `priv/*.so` via cargo)
- git + ca-certificates (rebar3 fetches deps from git)
- `protoc` is **not** required at build time , `rebar3 grpc gen` (provided by the `grpc_plugin` plugin) compiles the protos via the `gpb` library bundled by `emqx/grpc-erl`.

## Build

```bash
git clone https://codeberg.org/reckon-db-org/reckon-gateway.git
cd reckon-gateway

rebar3 grpc gen          # generate gRPC stubs from reckon-proto
rebar3 compile           # compiles the gateway + all deps, including reckon-db's NIFs
```

## Run in a shell

```bash
export RECKON_GATEWAY_PORT=50051
export RECKON_GATEWAY_CLUSTERS_PATH=""        # catalogue mode, no remotes
export RECKON_GATEWAY_STORE_ENABLED=false     # explicit off
rebar3 shell
```

Without those env vars set, `sys.config.src` substitution leaves `${...}` placeholders in app env. The gateway tolerates that (via `env_string/3`'s fall-through), but `rebar_prv_shell` itself scans the file with `re:run` before the BEAM boots , see the [gotchas](#gotchas) below.

## Build the OCI image locally

```bash
podman build -t reckon-gateway:dev .
podman run --rm -p 50051:50051 reckon-gateway:dev
```

The Dockerfile is multi-stage: builder (`erlang:27-slim` + Rust toolchain) produces a release tar; runtime (`debian:bookworm-slim`) ships only the release. The Rust toolchain is **not** in the runtime image.

## Tests

```bash
rebar3 eunit                                              # all suites
rebar3 eunit --module reckon_gateway_hybrid_mode_tests    # one suite
```

eunit 45/45 green is the floor before any release.

## Release

```bash
rebar3 as prod release
ls _build/prod/rel/reckon_gateway/bin/
```

The release embeds ERTS, so the resulting tarball needs no Erlang on the target host.

## Gotchas

- **No em-dashes in `sys.config.src`.** `rebar_prv_shell:until_var_end/1` calls `re:run` on the raw file bytes; byte 0xE2 0x80 0x94 makes the regex engine `badarg` and the BEAM never boots. Use `,` or `;` instead. (Project rule anyway , this is a release-blocker if violated.)
- **`rebar3 grpc gen` requires the `reckon_proto` git dep to be fetched first.** `rebar3 deps` or any compile-trigger pulls it. Without it the plugin runs with no protos to compile.
- **Rust toolchain version drift.** The Dockerfile pins `RUST_VERSION=1.90.0`. If your host Rust is older and you build outside Docker, you may hit NIF compile errors. Easiest fix: `rustup install 1.90.0 && rustup default 1.90.0` locally, or just use the Docker build.
