# sourcegraph/deploy developers guide

This repository describes how we build the standard Sourcegraph AMIs, VM images, etc. that we distribute through various cloud providers.

## Prerequisites

We use Hashicorp Packer to build the images:

1. [Install Packer](https://learn.hashicorp.com/tutorials/packer/get-started-install-cli?in=packer/aws-get-started#installing-packer).
2. [Authenticate with AWS](https://www.packer.io/plugins/builders/amazon#authentication):
   * In AWS, select the username dropdown in the top right of the page and choose _User credentials_ to create an access key.
   * In your `~/.zshrc`, `~/.bash_profile`, etc. add:

```
export AWS_ACCESS_KEY_ID="xxx"
export AWS_SECRET_ACCESS_KEY="yyy"
export AWS_DEFAULT_REGION="us-west-1"
```

## Creating a new AMI

### T-shirt sizing

We use T-shirt sizes which are [load tested with specific configurations](https://github.com/sourcegraph/reference-architecture-test).

To create an AMI for the given T-shirt size, follow the steps and reference this table:

| Size | Users  | Repositories | Largest Repo Size | Concurrent Users | Instance type | Storage   | IOPS   |
| ---- | ------ | ------------ | ----------------- | ---------------- | ------------- | --------- | ------ |
| XS   | 00,500 | 1,000        | 5GB               | 100              | m6a.2xlarge   | 500GB gp3 |        |
| S    | 01,000 | 10,000       | 23GB              | 200              | m6a.4xlarge   | 1TB gp3   |        |
| M    | 05,000 | 50,000       | 23GB              | 1,000            | m6a.8xlarge   | 2TB gp3   |        |
| L    | 10,000 | 100,000      | 35GB              | 2,000            | m6a.12xlarge  | 5TB io2   | 16,000 |
| XL   | 20,000 | 250,000      | 35GB              | 4,000            | m6a.24xlarge  | io2       | 16,000 |
| 2XL  | 40,000 | 500,000      | 60GB              | 8,000            | m6a.48xlarge  | io2       | 16,000 |

### Creating a VPC

<details>
<summary>If in us-west-2, this has already been done / you can skip this</summary>

1. Navigate to **VPC** > **Your VPCs** > **Create VPC**
2. **Resources to create**: choose **VPC and more**
3. **Name tag auto-generation**: rename **project** to **deploy-sourcegraph**
4. **IPv4 CIDR block**: 10.0.0.0/16
5. **IPv6 CIDR block**: none
6. **Tenancy**: default
7. **Number of Availability Zones (AZs)**: 2
8. **Number of public subnets**: 2
9. **Number of private subnets**: 2
9. **NAT gateways**: In 1 AZ
10. **VPC endpoints**: S3 Gateway
11. **Enable DNS hostnames**: checked
12. **Enable DNS resolution**: checked
13. **Create VPC**

</details>

### Creating an instance

1. Navigate to **Create an EC2 instance** page
2. **Name**: e.g. `sourcegraph-XXXXL (v9.9.9)` (if for testing, please add your name in the name too.)
3. **OS**: Latest Amazon Linux 2 (default) 64-bit (x86)
4. **Instance type**: refer to t-shirt size table
5. **Key pair**: _Proceed without a keypair (Not recommended)_ (IMPORTANT if building an AMI we will release to the public!)
6. **Network settings**:
  a. Choose _Edit_
  b. **VPC**: Choose the one ending in `(deploy-sourcegraph-vpc)`
  c. **Subnet**: Choose the one starting with `deploy-sourcegraph-subnet-private1` (**IMPORTANT**: it ends with `-private`)
  d. **Firewall**: **Select existing security group** > default
7. **Configure storage**:
  a. Make default (root) storage: 50 GiB gp3
  b. **Add new volume**: refer to t-shirt size table
8. **Advanced details**: expand and under **user data** enter this (replace the `size=` variable):

```sh
#!/usr/bin/env bash
set -exuo pipefail

size=override.XS.yaml

# If running as root, deescalate
if [ $UID -eq 0 ]; then
  cd /home/ec2-user
  chown ec2-user $0 # /var/lib/cloud/instance/scripts/part-001
  exec su ec2-user "$0" -- "$@"
  # nothing will be executed beyond here (exec replaces the running process)
fi

sudo yum update -y
sudo yum install -y git
git clone https://github.com/sourcegraph/deploy
cd deploy/
mv $size override.yaml
./install.sh
```

9. **Launch instance**

### Create the load balancer

<details>
<summary>If in us-west-2, this has already been done / you can skip this</summary>

1. Navigate to EC2 load balancers
2. **Create target group** (**You probably don't need to do this if you're in us-west-2, as it'd already be done.**)
  a. **Create target group**
  b. **Target type**: instances
  c. **Target group name**: deploy-sourcegraph-rollout
  d. **Protocol**: HTTPS : 443
  e. **VPC**: deploy-sourcegraph-vpc
  f. **Protocol version**: HTTP1
  g. **Next** > **Select running instance** > **Create target group**
2. **Create load balancer**: Application Load Balancer  (**You probably don't need to do this if you're in us-west-2, as it'd already be done.**)
  a. **Name**: `deploy-sourcegraph-rollout`
  b. **Scheme**: Internet-facing
  c. **VPC**: `deploy-sourcegraph-vpc`
  d. **Security group:** default
  e. **Listeners:** HTTPS, 443
  f. **Default action**: Forward to, deplpy-sourcegraph-rollout
  g. **Leave all as defaults, but select a TLS certificate** (rollout.sourcegraph.delivery)

</details>

### Point load balancer at instance, verify it is online

TODO(slimsag): write this section

## Debugging tips

### Networking

If facing networking challenges, it can be helpful to run ping etc. from inside a container in the cluster rather than on the host machine:

```sh
kubectl run -it --rm busybox --image=busybox sh
```

### Checking storage provisioner logs

If there are disk / persistent volume issues, you can check the storage provisioner like so:

```sh
kubectl -n local-path-storage logs -f -l app=local-path-provisioner
```

## Releases

### v4.0.0

#### Amazon EC2 AMIs

| Size | AMI ID                | Source                                            |
|------|-----------------------|---------------------------------------------------|
| XS   | ami-0ee5cdc5e89a4bee2 | 185007729374/sourcegraph-XS (v4.0.0) m6a.2xlarge  |
| L    | ami-021db30b6db9b0634 | 185007729374/sourcegraph-L (v4.0.0) m6a.12xlarge  |
| XL   | ami-04b10e0fabedb6eac | 185007729374/sourcegraph-XL (v4.0.0) m6a.24xlarge |
