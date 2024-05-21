# Development

## Prerequisites

We use Hashicorp Packer to build images:

1. [Install Packer](https://learn.hashicorp.com/tutorials/packer/get-started-install-cli?in=packer/aws-get-started#installing-packer).
2. Run `packer init` (ignore any warnings about unused variables here):

    ```
    packer init --var-file=./packer/dev/dev-variables.hcl ./packer/dev/dev-builder.pkr.hcl
    packer init --var-file=./packer/build-variables.hcl ./packer/aws/aws-builder.pkr.hcl
    packer init --var-file=./packer/build-variables.hcl ./packer/aws-latest/aws-builder.pkr.hcl
    packer init --var-file=./packer/build-variables.hcl ./packer/gcp/gcp-builder.pkr.hcl
    ```

3. [Authenticate with AWS](https://www.packer.io/plugins/builders/amazon#authentication):
   * In AWS, select the username dropdown in the top right of the page and choose _Security credentials_ to create an access key.
   * In your `~/.zshrc`, `~/.bash_profile`, etc. add:

    ```
    export AWS_ACCESS_KEY_ID="xxx"
    export AWS_SECRET_ACCESS_KEY="yyy"
    export AWS_DEFAULT_REGION="us-west-1"
    ```

## Project structure

* `doc/`: project documentation
* `packer/` AMI-specific build scripts (Packer files)
* `install/`: installation scripts ran on a machine to turn it into a Sourcegraph deployment
  * `install.sh`: primary installation script ran on machine to turn it into a Sourcegraph deployment. Installs k3s, runs helm install, etc.
  * `ingress.yaml`: Kubernetes ingress controller configuration
  * `reboot.sh`: a cronjob script ran on reboot to deal with the IP address / networking interfaces changing, upgrades, etc.
  * `override.<size>.yaml`: The Helm override file we use for a given T-shirt size.
* `build.sh`: builds all AMIs and publishes to all supported regions
* `lint.sh`: run code formatters, validate Packer files, etc.

## Building an AMI

To create an AMI for a given T-shirt size, follow the instructions in our development docs and refer to the following tables.

#### AWS

| Size | Users  | Repositories | Largest Repo Size | Concurrent Users | Instance type | Storage | IOPS    |
|------|--------|--------------|-------------------|------------------|---------------|---------|---------|
| XS   | 00,500 | 1,000        | 5GB               | 100              | m6a.2xlarge   | gp3     | default |
| S    | 01,000 | 10,000       | 23GB              | 200              | m6a.4xlarge   | gp3     | default |
| M    | 05,000 | 50,000       | 23GB              | 1,000            | m6a.8xlarge   | gp3     | default |
| L    | 10,000 | 100,000      | 35GB              | 2,000            | m6a.12xlarge  | io2     | 16,000  |
| XL   | 20,000 | 250,000      | 35GB              | 4,000            | m6a.24xlarge  | io2     | 16,000  |

#### Azure

Coming soon.

#### Google Compute Engine

Coming soon.

### A single AMI for testing

To build a single AMI for testing, update the `packer/dev/dev-variables.hcl` file with the instance version and instance size. This file provides the configuration which is used by `/packer/dev/dev-builder.pkr.hcl` to build a single image using XS instance setting. The name of the output AMI will be `"Sourcegraph-DEV-v${var.instance_version}-${formatdate("YYYY-MM-DD", timestamp())}"`, with the `NAME=ami-dev` tag.
Then run:

```
packer init packer/dev
packer build -var-file=/packer/dev/dev-variables.hcl /packer/dev/dev-builder.pkr.hcl
```


### Creation procedure

#### Batch

To create images for all cloud providers:

1. Update the `instance_version` variable on line 1 inside the [packer/build-variables.hcl file](../packer/build-variables.hcl) with the version number for the build
   * If trying to create a non-development build, also set `dev = false`.
2. Run `bash build.sh` from the root of this repository, which will:
   - Build the images for all sizes for each supported cloud provider
   - Copy them to the relevant regions
   - Mark them as public
3. Update [CHANGELOG.md](/CHANGELOG.md) with the list of image IDs you just published for the new version

#### AWS

1. Update the `instance_version` variable on line 1 inside the [packer/build-variables.hcl file](../packer/build-variables.hcl) with the version number for the build 
2. Run `packer build --var-file=./packer/build-variables.hcl ./packer/aws/aws-builder.pkr.hcl` from the root of this repository, which will:
   - Build the AWS AMIs for all sizes
   - Copy them to the relevant regions
3. Update [CHANGELOG.md](/CHANGELOG.md) with the list of AMI IDs you just published for the new version

#### AWS-Latest
1. Run `packer build --var-file=./packer/build-variables.hcl ./packer/aws-latest/aws-builder.pkr.hcl`
2. Copy the AMI ID output into `packer/aws-latest/_ami.yaml` - maintaining yaml structure
3. Run `cd packer/aws-latest/ && cat _ami.yaml | yj | ./_convert.py`
4. Copy the output to `packer/aws-latest/sg-basic.yaml` under the `Mappings` - `RegionMap`
5. Upload `packer/aws-latest/sg-basic.yaml` to the S3 bucket `sourcegraph-cloudformation` in the `Sourcegraph AMI` AWS account

#### Google Compute Engine

1. Update the `instance_version` variable on line 1 inside the [packer/build-variables.hcl file](../packer/build-variables.hcl) with the version number for the build 
2. Run `packer build --var-file=./packer/build-variables.hcl ./packer/gcp/gcp-builder.pkr.hcl` (insure version is _not_ specified) from the root of this repository, which will:
   - Build the Google Compute Machine Images for all sizes
   - Copy them to the storage buckets
   - Mark them as public
3. Update [CHANGELOG.md](/CHANGELOG.md) with the list of image IDs you just published for the new version, along with the links to the storage buckets

### Publishing a release

1. Once the release is published with all the commits merged, run the following commands on the `main` branch:

```bash
# e.g. git tag v4.0.1 
git tag v${instance_version}
# e.g. git push origin v4.0.1
git push origin v${instance_version}
```

> IMPORTANT: AMI will be published to **all** regions by default.

### Creating a subnet in a new region

If adding a new region, you may need to create a subnet with the `Name` tag `packer-build` (Packer finds the subnet based on the name):

1. Navigate to the **Subnets**
2. **Create subnet**
3. **VPC**: default
4. **Subnet name**: packer-build
5. **IPv4 CIDR block**: 10.0.0.0/24
