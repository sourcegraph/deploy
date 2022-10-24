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
    xs = object({
      instance_type    = string
      data_volume_type = string
      data_volume_size = string
    })
    s = object({
      instance_type    = string
      data_volume_type = string
      data_volume_size = string
    })
    m = object({
      instance_type    = string
      data_volume_type = string
      data_volume_size = string
    })
    l = object({
      instance_type    = string
      data_volume_type = string
      data_volume_size = string
    })
    xl = object({
      instance_type    = string
      data_volume_type = string
      data_volume_size = string
    })
  })
  default = { 
    xs = {
        instance_type = "m6a.2xlarge"
        data_volume_type = "gp3"
        data_volume_size = 500
    },
    s = {
        instance_type = "m6a.4xlarge"
        data_volume_type = "gp3"
        data_volume_size = 500
    },
    m = {
        instance_type = "m6a.8xlarge"
        data_volume_type = "gp3"
        data_volume_size = 500
    },
    l = {
        instance_type = "m6a.12xlarge"
        data_volume_type = "io2"
        data_volume_size = 500
    },
    xl = {
        instance_type = "m6a.24xlarge"
        data_volume_type = "io2"
        data_volume_size = 500
    }
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

source "amazon-ebs" "XS" {
  ami_name                     = "Sourcegraph-XS (latest) ${var.instance_sizes.xs.instance_type}"
  ami_description              = "Sourcegraph-XS (latest) ${var.instance_sizes.xs.instance_type}"
  instance_type                = var.instance_sizes.xs.instance_type
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
      "tag:Name" : "default"
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
    volume_type           = var.instance_sizes.xs.data_volume_type
    volume_size           = var.instance_sizes.xs.data_volume_size
  }
  tags                    = {
    Name                  = "production"
    Version               = "latest"
  }
}

source "amazon-ebs" "S" {
  ami_name                     = "Sourcegraph-S (latest) ${var.instance_sizes.s.instance_type}"
  ami_description              = "Sourcegraph-S (latest) ${var.instance_sizes.s.instance_type}"
  instance_type                = var.instance_sizes.s.instance_type
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
    volume_type           = var.instance_sizes.s.data_volume_type
    volume_size           = var.instance_sizes.s.data_volume_size
  }
  tags                    = {
    Name                  = "production"
    Version               = var.instance_version
  }
}

source "amazon-ebs" "M" {
  ami_name                     = "Sourcegraph-M (latest) ${var.instance_sizes.m.instance_type}"
  ami_description              = "Sourcegraph-M (latest) ${var.instance_sizes.m.instance_type}"
  instance_type                = var.instance_sizes.m.instance_type
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
    delete_on_termination = false
    device_name           = "/dev/xvda"
    encrypted             = false

    volume_type = "gp3"
    volume_size = 50
  }
  launch_block_device_mappings {
    device_name           = "/dev/sdb"
    encrypted             = false
    delete_on_termination = false
    volume_type           = var.instance_sizes.m.data_volume_type
    volume_size           = var.instance_sizes.m.data_volume_size
  }
  tags                    = {
    Name                  = "production"
    Version               = var.instance_version
  }
}

source "amazon-ebs" "L" {
  ami_name                     = "Sourcegraph-L (latest) ${var.instance_sizes.l.instance_type}"
  ami_description              = "Sourcegraph-L (latest) ${var.instance_sizes.l.instance_type}"
  instance_type                = var.instance_sizes.l.instance_type
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
    volume_type           = "gp3"
    volume_size           = 50
  }
  launch_block_device_mappings {
    device_name           = "/dev/sdb"
    encrypted             = false
    delete_on_termination = false
    volume_type           = var.instance_sizes.l.data_volume_type
    volume_size           = var.instance_sizes.l.data_volume_size
  }
  tags                    = {
    Name                  = "production"
    Version               = var.instance_version
  }
}

source "amazon-ebs" "XL" {
  ami_name                     = "Sourcegraph-XL (latest) ${var.instance_sizes.xl.instance_type}"
  ami_description              = "Sourcegraph-XL (latest) ${var.instance_sizes.xl.instance_type}"
  instance_type                = var.instance_sizes.xl.instance_type
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
    volume_type           = var.instance_sizes.xl.data_volume_type
    volume_size           = var.instance_sizes.xl.data_volume_size
  }
  tags                    = {
    Name                  = "production"
    Version               = "latest"
  }
}

source "amazon-ebs" "DEV" {
  ami_name                     = "Sourcegraph-DEV-XS (latest) ${var.instance_sizes.xs.instance_type}"
  ami_description              = "Sourcegraph-DEV-XS (latest) ${var.instance_sizes.xs.instance_type}"
  instance_type                = var.instance_sizes.xs.instance_type
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
    delete_on_termination = false
    volume_type           = var.instance_sizes.xs.data_volume_type
    volume_size           = var.instance_sizes.xs.data_volume_size
  }
  tags                    = {
    Name                  = "dev"
    Version               = "latest"
  }
}

build {
  name = "sourcegraph-amis"
  sources = var.dev ? ["source.amazon-ebs.DEV"] : [
    "source.amazon-ebs.XS",
    "source.amazon-ebs.S",
    "source.amazon-ebs.M",
    "source.amazon-ebs.L",
    "source.amazon-ebs.XL"
  ]

  // Move the install.sh script to VM to run on next reboot 
  provisioner "file" {
    source = "./packer/aws-latest/install.sh"
    destination = "/home/ec2-user/install.sh"
  }

  provisioner "shell" {
    except              = ["amazon-ebs.DEV"]
    environment_vars = ["INSTANCE_SIZE=${upper(source.name)}"]
    scripts          = ["./packer/aws-latest/init.sh"]
  }
  provisioner "shell" {
    only              = ["amazon-ebs.DEV"]
    environment_vars  = ["INSTANCE_SIZE=XS"]
    scripts           = ["./packer/aws-latest/init.sh"]
  }
}