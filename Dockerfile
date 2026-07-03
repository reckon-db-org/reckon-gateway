# ReckonDB gRPC Gateway
# Multi-stage build: compile + release, then slim runtime

# ── Builder ──
FROM erlang:27-slim AS builder

# git/curl/ca-certificates: rebar3 deps fetching
# build-essential: required by `cargo build` to link the NIF .so files
# Rust toolchain installed below; needed at build time so reckon-db
# can compile its embedded NIFs (reckon_db_*_nif crates under
# native/) into priv/ during `rebar3 compile`. Without Rust here the
# build would silently fall back to pure-Erlang implementations and
# the cluster would lose 3-15× speedups on hot crypto/hash/archive
# paths.
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates build-essential && \
    rm -rf /var/lib/apt/lists/*

# Rust via rustup, pinned to a recent stable. -y/--default-toolchain
# avoids the interactive prompt; --profile minimal skips docs to
# keep the layer small. Final image size impact is zero (this is a
# multi-stage build — only the built release is copied to runtime).
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH \
    RUST_VERSION=1.90.0
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain ${RUST_VERSION} --profile minimal \
    && rustc --version && cargo --version

# Install rebar3
RUN curl -fsSL https://s3.amazonaws.com/rebar3/rebar3 -o /usr/local/bin/rebar3 && \
    chmod +x /usr/local/bin/rebar3

WORKDIR /app

# Copy dependency specs first for layer caching
COPY rebar.config rebar.lock* ./
RUN rebar3 deps

# Copy source (protos no longer live in this repo — they're fetched
# from the reckon-proto git dep during `rebar3 deps' above, ending up
# at _build/default/lib/reckon_proto/proto/ where grpc_plugin reads
# them).
COPY config/ config/
COPY include/ include/
COPY priv/ priv/
COPY src/ src/

# Generate gRPC stubs and build release. The `rebar3 compile` step
# (invoked by `release`) runs reckon-db's pre_hook which builds the
# six Rust NIFs into _build/default/lib/reckon_db/priv/*.so. Those
# .so files get bundled into the release tarball by relx.
RUN rebar3 grpc gen && \
    rebar3 as prod release

# ── Runtime ──
FROM debian:bookworm-slim AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
    libncurses6 openssl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash app

WORKDIR /app

COPY --from=builder --chown=app:app /app/_build/prod/rel/reckon_gateway .

# /etc/reckon-gateway/clusters.eterm — operator-mounted; cookies live
# here. The image ships without it; the deploy unit bind-mounts the
# per-host file (chmod 0600 + read-only).
RUN mkdir -p /etc/reckon-gateway && chown -R app:app /etc/reckon-gateway

USER app

# gRPC port
EXPOSE 50051

# HTTP/JSON REST API + admin UI + SSE (separate listener from gRPC).
EXPOSE 8080

# Erlang distribution ports (cluster catalogue uses per-peer cookies
# to talk to N disjoint Erlang clusters at once).
EXPOSE 4369
EXPOSE 9100-9200

# Runtime config (overridable via the container environment).
#
# Catalogue mode (default, behaves like 0.5): the gateway holds NO
# data. It joins one or more remote Erlang dist clusters (per the
# clusters.eterm at RECKON_GATEWAY_CLUSTERS_PATH) and proxies every
# gRPC request via rpc:call to whichever BEAM owns the target store.
ENV RECKON_GATEWAY_PORT=50051
ENV RECKON_GATEWAY_HTTP_PORT=8080
ENV RECKON_GATEWAY_CLUSTERS_PATH=/etc/reckon-gateway/clusters.eterm

# Embedded-store mode (opt-in, 0.6+): set STORE_ENABLED=true and the
# gateway boots a local reckon_db store under its supervisor and
# advertises it in the catalogue under LOCAL_CLUSTER_ID. STORE_MODE
# `single` runs standalone; `cluster` participates in Ra quorum via
# discovery (requires RECKON_DB_CLUSTER_SECRET + matching RELEASE_COOKIE
# across peers).
ENV RECKON_GATEWAY_STORE_ENABLED=false
ENV RECKON_GATEWAY_STORE_ID=local_store
ENV RECKON_GATEWAY_DATA_DIR=/data
ENV RECKON_GATEWAY_STORE_MODE=single
ENV RECKON_GATEWAY_LOCAL_CLUSTER_ID=local

# Optional: full #store_config{} declaration (pools, timeout, payload
# indexes for CCC, integrity/HMAC). Absent file => env-only config.
# Bind-mount the per-host store.eterm here, read-only. See
# docs/store-config.md. Advanced fields (payload indexes, integrity)
# can ONLY be declared via this file.
ENV RECKON_GATEWAY_STORE_PATH=/etc/reckon-gateway/store.eterm

# RECKON_DB_CLUSTER_SECRET is intentionally NOT declared here. It's a
# shared-secret consumed by `reckon_db_discovery` in cluster mode, and
# baking the name (even with an empty default) trips the Docker
# `SecretsUsedInArgOrEnv` lint AND lets a stale image carry the name
# into envs the operator forgot to override. Operators MUST supply it
# at runtime via compose `environment:`, k8s `secretKeyRef`, systemd
# `EnvironmentFile=`, or `--env-file` , never bake it into the image.

# Persistent volume for Khepri/Ra WAL + state. Single mount per
# container (one store per container). Operator binds /data to a
# persistent host volume in compose/k8s.
VOLUME /data

# Ra ports (used only when STORE_MODE=cluster). Discovery picks
# from this range per node, and peer-to-peer dist traffic flows on
# 9100-9200 (already exposed above).
EXPOSE 5000-5100

# BEAM distribution. NODE_NAME must be unique per host. In catalogue
# mode RELEASE_COOKIE is unused for remote clusters (per-peer cookies
# from clusters.eterm override). In cluster STORE_MODE, RELEASE_COOKIE
# IS the embedded-store quorum's auth and MUST match across peers.
ENV NODE_NAME=reckon_gateway@127.0.0.1
ENV RELEASE_COOKIE=reckon_gateway_unused_default

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD /app/bin/reckon_gateway ping || exit 1

ENTRYPOINT ["/app/bin/reckon_gateway"]
CMD ["foreground"]
