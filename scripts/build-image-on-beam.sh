#!/usr/bin/env bash
#
# Build the reckon-gateway docker image on a beam node (the dev
# laptop has no docker daemon, so we offload the build). Rsyncs the
# repo, runs `docker build`, tags with the version from app.src and
# also as `latest`.
#
# Usage: ./build-image-on-beam.sh [<host>]
#   host — defaults to beam01.lab

set -eu

HOST="${1:-beam01.lab}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REMOTE_DIR="/home/rl/reckon-gateway-build"

VERSION=$(grep -E '^\s*\{vsn,' "${REPO_DIR}/src/reckon_gateway.app.src" | sed -E 's/.*"([^"]+)".*/\1/')
echo "==> Building reckon-gateway ${VERSION} on ${HOST}"

rsync -az --delete \
    --exclude=_build \
    --exclude=.git \
    --exclude=doc \
    "${REPO_DIR}/" "rl@${HOST}:${REMOTE_DIR}/"

ssh "rl@${HOST}" "cd ${REMOTE_DIR} && docker build -t reckon-gateway:${VERSION} -t reckon-gateway:latest ."

echo
echo "==> Done. Image reckon-gateway:${VERSION} built on ${HOST}."
echo "    Distribute with reckon-cluster-compose/scripts/distribute-from-beam.sh ${VERSION} ${HOST}"
