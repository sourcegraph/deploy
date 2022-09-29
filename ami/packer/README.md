# Sourcegraph AMIs Builder - Packer

This directory contains the scripts to build Sourcegraph images automatically for each instance size using [Packer](https://learn.hashicorp.com/packer).

## Steps

1. Install Packer following the [official installation docs](https://learn.hashicorp.com/tutorials/packer/get-started-install-cli?in=packer/docker-get-started)
2. Update the `instance_version` variable with the version number for the build inside the [ami-variables.hcl file](ami-variables.hcl)
3. Run the command below to start the image/AMI building process from the root of this directory:
    ```bash
    packer build --var-file=ami-variables.hcl ami-builder.pkr.hcl
    ```
