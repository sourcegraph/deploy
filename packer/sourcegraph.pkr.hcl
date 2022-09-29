packer {
  required_plugins {
    amazon = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "override_file" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "build_in_region" {
  type = string
}

variable "ami_name" {
  type = string
}

variable "data_volume_type" {
  type = string
}

variable "data_volume_size" {
  type = number
}

source "amazon-ebs" "sourcegraph" {
  ami_name      = "${ var.ami_name }-${ formatdate("YYYY-MM-DD", timestamp()) }"
  instance_type = var.instance_type
  region        = var.build_in_region
  source_ami_filter {
    filters = {
      name                = "amzn2-ami-kernel-*-hvm-*-x86_64-gp2"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }
  associate_public_ip_address = true
  subnet_filter {
    filters = {
      "tag:Name" : "packer-build"
    }
    most_free = true
    random    = false
  }
  ssh_username = "ec2-user"
  launch_block_device_mappings {
    delete_on_termination = true
    device_name           = "/dev/xvda"
    encrypted             = false

    volume_type = "gp3"
    volume_size = 50
  }
  launch_block_device_mappings {
    device_name = "/dev/sdb"
    encrypted   = false
    volume_type = var.data_volume_type
    volume_size = var.data_volume_size
  }
}

build {
  name = "sourcegraph"
  sources = [
    "source.amazon-ebs.sourcegraph"
  ]
  provisioner "shell" {
    inline = [<<EOF
#!/usr/bin/env bash
set -exuo pipefail

size=${var.override_file}

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
  EOF
    ]
  }
}
