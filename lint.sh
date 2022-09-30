#!/usr/bin/env bash
set -exuo pipefail

packer fmt -recursive -write .

packer validate --var-file=./ami/ami-variables.hcl ./ami/ami-builder.pkr.hcl
