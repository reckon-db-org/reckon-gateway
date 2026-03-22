# ReckonDB gRPC Gateway
# Multi-stage build: compile + release, then slim runtime

# ── Builder ──
FROM erlang:27-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Install rebar3
RUN curl -fsSL https://s3.amazonaws.com/rebar3/rebar3 -o /usr/local/bin/rebar3 && \
    chmod +x /usr/local/bin/rebar3

WORKDIR /app

# Copy dependency specs first for layer caching
COPY rebar.config rebar.lock* ./
RUN rebar3 deps

# Copy source
COPY config/ config/
COPY proto/ proto/
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

ENV RECKON_GATEWAY_PORT=50051
ENV RECKON_DB_DATA_DIR=/app/data

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD /app/bin/reckon_gateway ping || exit 1

ENTRYPOINT ["/app/bin/reckon_gateway"]
CMD ["foreground"]
