#!/usr/bin/env bash
set -exuo pipefail

# Build Go binaries
env GOOS=linux GOARCH=amd64 go build -o cmd/install/bin/sg-init ./cmd/init/
env GOOS=linux GOARCH=amd64 go build -o cmd/install/bin/sourcegraphd ./cmd/sourcegraphd/
env GOOS=linux GOARCH=amd64 go build -o bin/sginstall ./cmd/install/
