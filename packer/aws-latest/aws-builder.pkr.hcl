packer {
  required_plugins {
    amazon = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "dev" {
  type        = bool
  default     = true
}

variable "instance_sizes" {
  type = object({
    gp3 = object({
      instance_type    = string
      data_volume_type = string
      data_volume_size = string
    })
    io2 = object({
      instance_type    = string
      data_volume_type = string
      data_volume_size = string
    })
  })
  default = { 
    gp3 = {
        instance_type = "m6a.2xlarge"
        data_volume_type = "gp3"
        data_volume_size = 500
    },
    io2 = {
        instance_type = "m6a.2xlarge"
        data_volume_type = "io2"
        data_volume_size = 500
    },
  }
}

variable "build_in_region" {
  description = "Region to build the launch instances"
  type        = string
  default     = "us-west-2"
}

variable "ami_regions_aws" {
  description   = "Region to copy the AMIs to"
  default       = {
    dev         = [ "us-west-2" ],
    production  = [
      "us-west-1",
      "us-west-2",
      "us-east-1",
      "us-east-2",
      "eu-west-1",
      "eu-central-1",
      "ap-northeast-1",
      "ap-northeast-2",
      "ap-southeast-1",
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
  regions            = var.dev ? var.ami_regions_aws.dev : var.ami_regions_aws.production
}

source "amazon-ebs" "gp3" {
  ami_name                     = "Sourcegraph (latest) ${var.instance_sizes.gp3.data_volume_type}"
  ami_description              = "Sourcegraph (latest) ${var.instance_sizes.gp3.data_volume_type}"
  force_deregister             = true
  force_delete_snapshot        = true
  instance_type                = var.instance_sizes.gp3.instance_type
  region                       = var.build_in_region
  ami_regions                  = local.regions
  ami_groups                   = ["all"]
  associate_public_ip_address  = true
  source_ami_filter {
    filters                    = {
      name                     = "amzn2-ami-kernel-*-hvm-*-x86_64-gp2"
      root-device-type         = "ebs"
      virtualization-type      = "hvm"
    }
    most_recent                = true
    owners                     = ["amazon"]
  }
  subnet_filter {
    filters                    = {
      "tag:Name" : "packer-build"
    }
    most_free                  = true
    random                     = false
  }
  ssh_username                 = "ec2-user"
  launch_block_device_mappings {
    delete_on_termination      = true
    device_name                = "/dev/xvda"
    encrypted                  = false
    volume_type                = "gp3"
    volume_size                = 50
  }
  launch_block_device_mappings {
    device_name           = "/dev/sdb"
    encrypted             = false
    delete_on_termination = false
    volume_type           = var.instance_sizes.gp3.data_volume_type
    volume_size           = var.instance_sizes.gp3.data_volume_size
  }
  tags                    = {
    Name                  = "production"
    Version               = "latest"
  }
}

source "amazon-ebs" "io2" {
  ami_name                     = "Sourcegraph (latest) ${var.instance_sizes.io2.data_volume_type}"
  ami_description              = "Sourcegraph (latest) ${var.instance_sizes.io2.data_volume_type}"
  force_deregister             = true
  force_delete_snapshot        = true
  instance_type                = var.instance_sizes.io2.instance_type
  region                       = var.build_in_region
  ami_groups                   = ["all"]
  ami_regions                  = local.regions
  associate_public_ip_address  = true
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
  ssh_username                 = "ec2-user"
  launch_block_device_mappings {
    delete_on_termination = true
    device_name           = "/dev/xvda"
    encrypted             = false
    volume_type = "gp3"
    volume_size = 50
  }
  launch_block_device_mappings {
    device_name           = "/dev/sdb"
    encrypted             = false
    delete_on_termination = false
    iops                  = "16000"
    volume_type           = var.instance_sizes.io2.data_volume_type
    volume_size           = var.instance_sizes.io2.data_volume_size
  }
  tags                    = {
    Name                  = "production"
    Version               = "latest"
  }
}

source "amazon-ebs" "DEV" {
  ami_name                     = "Sourcegraph-DEV (latest) ${var.instance_sizes.gp3.instance_type}"
  ami_description              = "Sourcegraph-DEV (latest) ${var.instance_sizes.gp3.instance_type}"
  force_deregister             = true
  force_delete_snapshot        = true
  instance_type                = var.instance_sizes.gp3.instance_type
  region                       = var.build_in_region
  ami_regions                  = local.regions
  associate_public_ip_address  = true
  source_ami_filter {
    filters                    = {
      name                     = "amzn2-ami-kernel-*-hvm-*-x86_64-gp2"
      root-device-type         = "ebs"
      virtualization-type      = "hvm"
    }
    most_recent                = true
    owners                     = ["amazon"]
  }
  subnet_filter {
    filters                    = {
      "tag:Name" : "packer-build"
    }
    most_free                  = true
    random                     = false
  }
  ssh_username                 = "ec2-user"
  launch_block_device_mappings {
    delete_on_termination      = true
    device_name                = "/dev/xvda"
    encrypted                  = false
    volume_type                = "gp3"
    volume_size                = 50
  }
  launch_block_device_mappings {
    device_name           = "/dev/sdb"
    encrypted             = false
    delete_on_termination = true # Delete Dev disk on termination
    volume_type           = var.instance_sizes.gp3.data_volume_type
    volume_size           = var.instance_sizes.gp3.data_volume_size
  }
  tags                    = {
    Name                  = "dev"
    Version               = "latest"
  }
}

build {
  name = "sourcegraph-amis"
  sources = var.dev ? ["source.amazon-ebs.DEV"] : [
    "source.amazon-ebs.gp3",
    "source.amazon-ebs.io2",
  ]

  // Move the install.sh script to VM to run on next reboot 
  provisioner "file" {
    source = "./packer/aws-latest/install.sh"
    destination = "/home/ec2-user/install.sh"
  }

  provisioner "shell" {
    scripts          = ["./packer/aws-latest/init.sh"]
  }

  provisioner "shell" {
    inline = ["sudo rm /home/ec2-user/.ssh/authorized_keys && sudo rm /root/.ssh/authorized_keys"]
  }
}
