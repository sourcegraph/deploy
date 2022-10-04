#!/usr/bin/env bash
set -exuo pipefail

packer build --var-file=/ami/packer/ami-variables.hcl /ami/packer/ami-builder.pkr.hcl
