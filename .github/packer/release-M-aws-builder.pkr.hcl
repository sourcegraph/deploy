packer {
  required_plugins {
    amazon = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "dev" {
  type    = bool
  default = true
}

variable "instance_version" {
  description = "Version number for the AMI build"
  type        = string
}


variable "build_in_region" {
  description = "Region to build the launch instances"
  type        = string
  default     = "us-west-2"
}

variable "ami_regions_aws" {
  description = "Region to copy the AMIs to"
  default = {
    production = [
      "us-west-1",
      "us-west-2",
      "us-east-1",
      "us-east-2",
      "eu-west-1",
      "eu-central-1",
      "ap-northeast-1",
      "ap-northeast-2",
      // "ap-southeast-1", # excluded as Public AMI quota too low
      "ap-southeast-2",
      "ap-south-1",
      "sa-east-1",
      "eu-west-2",
      "eu-west-3",
      "eu-south-1",
      "eu-north-1",
      "ca-central-1",
      "me-south-1",
      "me-central-1",
      "ap-east-1",
      "af-south-1",
      "ap-southeast-3"
    ]
  }
}

locals {
  regions = var.ami_regions_aws.production
}

source "amazon-ebs" "M" {
  skip_create_ami             = var.dev ? true : false
  ami_name                    = "Sourcegraph-M (v${var.instance_version}) m6a.8xlarge"
  ami_description             = "Sourcegraph-M (v${var.instance_version}) m6a.8xlarge"
  instance_type               = "m6a.8xlarge"
  region                      = var.build_in_region
  ami_groups                  = ["all"]
  ami_regions                 = local.regions
  associate_public_ip_address = true
  source_ami_filter {
    filters = {
      name                = "amzn2-ami-kernel-*-hvm-*-x86_64-gp2"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }
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
    volume_type           = "gp3"
    volume_size           = 50
  }
  launch_block_device_mappings {
    device_name           = "/dev/sdb"
    encrypted             = false
    delete_on_termination = false
    volume_type           = "gp3"
    volume_size           = 500
  }
  tags = {
    Name    = "production"
    Version = var.instance_version
  }
}

build {
  name    = "sourcegraph-amis"
  sources = ["source.amazon-ebs.M"]
  provisioner "shell" {
    environment_vars = ["INSTANCE_SIZE=${upper(source.name)}", "INSTANCE_VERSION=${var.instance_version}"]
    scripts          = ["../../install/install.sh"]
  }
}
