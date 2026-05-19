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
COPY src/ src/
COPY include/ include/

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

# Erlang distribution ports (cluster catalogue uses per-peer cookies
# to talk to N disjoint Erlang clusters at once).
EXPOSE 4369
EXPOSE 9100-9200

# Runtime config — overridable via the container environment.
#
# Catalogue mode (0.5+): the gateway holds NO data. It joins one or
# more remote Erlang dist clusters (per the clusters.eterm at
# RECKON_GATEWAY_CLUSTERS_PATH) and proxies every gRPC request via
# rpc:call to whichever BEAM owns the target store.
ENV RECKON_GATEWAY_PORT=50051
ENV RECKON_GATEWAY_CLUSTERS_PATH=/etc/reckon-gateway/clusters.eterm

# BEAM distribution. NODE_NAME must be unique per host; RELEASE_COOKIE
# is unused for clusters.eterm targets (per-peer cookies override) but
# must still be set so the BEAM can register a name.
ENV NODE_NAME=reckon_gateway@127.0.0.1
ENV RELEASE_COOKIE=reckon_gateway_unused_default

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD /app/bin/reckon_gateway ping || exit 1

ENTRYPOINT ["/app/bin/reckon_gateway"]
CMD ["foreground"]
