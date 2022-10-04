#!/usr/bin/env bash
set -exuo pipefail

packer fmt -recursive -write .

packer validate --var-file=/ami/packer/ami-variables.hcl /ami/packer/ami-builder.pkr.hcl
