# Manually creating a new AMI

## Creating a VPC

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

## Creating an instance

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
  b. **Add new volume**: 500 GiB, refer to t-shirt size table
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
cd deploy/install
mv $size override.yaml
./install.sh
```

9. **Launch instance**

## Create the load balancer

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

**Now point the load balancer at the instance to verify it is working.**
