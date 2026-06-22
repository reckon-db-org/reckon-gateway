#!/usr/bin/env bash
# Build the reckon-gateway image locally and push to ghcr.io.
# Run from the repo root.
set -euo pipefail

IMAGE="ghcr.io/reckon-db-org/reckon-gateway"
GIT_SHA=$(git rev-parse --short HEAD)

echo "Building ${IMAGE}:latest (${GIT_SHA})..."
docker build --platform linux/amd64 -t "${IMAGE}:latest" -t "${IMAGE}:${GIT_SHA}" .

echo ""
echo "Pushing..."
docker push "${IMAGE}:latest"
docker push "${IMAGE}:${GIT_SHA}"

echo ""
echo "Done: ${IMAGE}:latest (${GIT_SHA})"
