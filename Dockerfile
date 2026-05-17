# ReckonDB gRPC Gateway
# Multi-stage build: compile + release, then slim runtime

# ── Builder ──
FROM erlang:27-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

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

# Generate gRPC stubs and build release
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

# Data directory for ReckonDB event store
RUN mkdir -p /app/data && chown -R app:app /app/data

USER app

# gRPC port
EXPOSE 50051

# Erlang distribution ports (for clustering)
EXPOSE 4369
EXPOSE 9100-9200

# ReckonDB discovery (UDP multicast)
EXPOSE 45892/udp

# Runtime config — all overridable via the container's environment.
# Defaults make the image run standalone (single-node, default cookie).
# For clustered deployments set RECKON_DB_STORE_MODE=cluster + a unique
# NODE_NAME per host + a shared RELEASE_COOKIE + a shared
# RECKON_DB_CLUSTER_SECRET.
ENV RECKON_GATEWAY_PORT=50051
ENV RECKON_DB_DATA_DIR=/app/data

# BEAM distribution — long names. NODE_NAME is the full -name value.
# Standalone default uses localhost; cluster overrides this per host.
ENV NODE_NAME=reckon_gateway@127.0.0.1
ENV RELEASE_COOKIE=reckon_gateway_default_cookie_change_in_prod

# reckon-db store mode + cluster discovery params.
ENV RECKON_DB_STORE_MODE=single
ENV RECKON_DB_CLUSTER_PORT=45892
ENV RECKON_DB_CLUSTER_MULTICAST_ADDR=239.255.0.1
ENV RECKON_DB_CLUSTER_SECRET=reckon_db_default_secret_change_in_prod

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD /app/bin/reckon_gateway ping || exit 1

ENTRYPOINT ["/app/bin/reckon_gateway"]
CMD ["foreground"]
