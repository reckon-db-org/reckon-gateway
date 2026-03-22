#!/usr/bin/env bash
set -euo pipefail

# Install protoc (protobuf compiler) and Go gRPC plugins
# No sudo needed — installs to ~/go/bin and ~/.local

PROTOC_VERSION="28.3"
ARCH="linux-x86_64"

echo "==> Installing protoc ${PROTOC_VERSION} to ~/.local..."
cd /tmp
curl -fsSL "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-${ARCH}.zip" -o protoc.zip
mkdir -p "${HOME}/.local/bin" "${HOME}/.local/include"
unzip -o protoc.zip -d protoc-install
cp protoc-install/bin/protoc "${HOME}/.local/bin/"
cp -r protoc-install/include/* "${HOME}/.local/include/"
rm -rf protoc.zip protoc-install

echo "==> Installing Go gRPC plugins..."
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

echo "==> Verifying..."
"${HOME}/.local/bin/protoc" --version
which protoc-gen-go
which protoc-gen-go-grpc

echo "==> Done."
