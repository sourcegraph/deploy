#!/usr/bin/env bash
set -exuo pipefail

packer fmt -recursive -write .

packer validate -var-file=./packer/xs-m5a.hcl ./packer/sourcegraph.pkr.hcl
packer validate -var-file=./packer/xs-m6a.hcl ./packer/sourcegraph.pkr.hcl
