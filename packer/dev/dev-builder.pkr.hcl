packer {
  required_plugins {
    amazon = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "instance_version" {
  description = "Version number for the AMI build"
  type        = string
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
      instance_type    = "m6a.2xlarge"
      data_volume_type = "gp3"
      data_volume_size = 500
    },
    s = {
      instance_type    = "m6a.4xlarge"
      data_volume_type = "gp3"
      data_volume_size = 500
    },
    m = {
      instance_type    = "m6a.8xlarge"
      data_volume_type = "gp3"
      data_volume_size = 500
    },
    l = {
      instance_type    = "m6a.12xlarge"
      data_volume_type = "io2"
      data_volume_size = 500
    },
    xl = {
      instance_type    = "m6a.24xlarge"
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

variable "ami_regions" {
  description = "Region to copy the AMIs to"
  type        = list(string)
  default     = ["us-west-2"]
}

source "amazon-ebs" "dev" {
  ami_name                    = "Sourcegraph-DEV-v${var.instance_version}-${formatdate("YYYY-MM-DD", timestamp())}"
  ami_description             = "Sourcegraph-DEV-v${var.instance_version}-${formatdate("YYYY-MM-DD", timestamp())}"
  force_deregister            = true
  force_delete_snapshot       = true
  instance_type               = var.instance_sizes.xs.instance_type
  region                      = var.build_in_region
  ami_regions                 = var.ami_regions
  ami_groups                  = ["all"]
  associate_public_ip_address = true
  source_ami_filter {
    filters = {
      name                = "al2023-ami-*-kernel-*-x86_64"
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
    volume_type           = var.instance_sizes.xs.data_volume_type
    volume_size           = var.instance_sizes.xs.data_volume_size
  }
  tags = {
    Name    = "ami-dev"
    Version = var.instance_version
  }
}


build {
  name = "sourcegraph-amis"
  sources = [
    "source.amazon-ebs.dev",
  ]

  provisioner "file" {
    source      = "./bin/sginstall"
    destination = "/tmp/sginstall"
  }

  provisioner "shell" {
    only   = ["amazon-ebs.dev"]
    inline = ["sudo /tmp/sginstall install"]
  }

  provisioner "shell" {
    inline = ["sudo rm /home/ec2-user/.ssh/authorized_keys && sudo rm /root/.ssh/authorized_keys"]
  }
}
