#!/usr/bin/env bash
set -euo pipefail

# Generate Go gRPC stubs from proto files
# Requires: protoc, protoc-gen-go, protoc-gen-go-grpc

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
PROTO_DIR="${REPO_DIR}/proto"
OUT_DIR="${REPO_DIR}/gen/go/gatewayv1"

PROTOC="${HOME}/.local/bin/protoc"
if ! command -v "${PROTOC}" &>/dev/null; then
    PROTOC="protoc"
fi

echo "==> Generating Go stubs from ${PROTO_DIR}..."
mkdir -p "${OUT_DIR}"

"${PROTOC}" \
    --proto_path="${PROTO_DIR}" \
    --go_out="${OUT_DIR}" \
    --go_opt=paths=source_relative \
    --go-grpc_out="${OUT_DIR}" \
    --go-grpc_opt=paths=source_relative \
    "${PROTO_DIR}"/*.proto

echo "==> Generated $(ls "${OUT_DIR}"/*.go | wc -l) Go files in ${OUT_DIR}"

# Initialize/update Go module if needed
if [ ! -f "${OUT_DIR}/go.mod" ]; then
    echo "==> Initializing Go module..."
    cd "${OUT_DIR}"
    go mod init github.com/reckon-db-org/reckon-gateway/gen/go/gatewayv1
    go mod tidy
fi

echo "==> Done."
