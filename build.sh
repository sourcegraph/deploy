#!/usr/bin/env bash
set -exuo pipefail

packer build --var-file=./ami/ami-variables.hcl ./ami/ami-builder.pkr.hcl
