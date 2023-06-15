#!/usr/bin/env bash
set -exuo pipefail

version=$1

# Build Go binaries
env GOOS=linux GOARCH=amd64 go build -ldflags "-X main.sgversion=$version" -o cmd/install/bin/sg-init ./cmd/init/
env GOOS=linux GOARCH=amd64 go build -ldflags "-X main.sgversion=$version" -o cmd/install/bin/sourcegraphd ./cmd/sourcegraphd/
env GOOS=linux GOARCH=amd64 go build -ldflags "-X main.sgversion=$version" -o bin/sginstall ./cmd/install/
