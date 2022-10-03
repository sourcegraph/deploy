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
  default = "4.0.1"
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
}

variable "ami_tags" {
  type = object({
    Name = string
    Version = string
  })
  default = {
    Name = "production"
    Version = var.instance_version
  }
}

variable "ami_description" {
  type    = string
  default = "Sourcegraph AMI"
}

variable "build_in_region" {
  description = "Region to build the launch instances"
  type        = string
  default     = "us-west-2"
}

variable "ami_regions" {
  description = "Region to copy the AMIs to"
  type        = list(string)
  default = [ "us-west-1", "us-west-2", "us-east-1", "us-east-2"]
}

source "amazon-ebs" "size-xs" {
  ami_name                     = "Sourcegraph-XS (v${var.instance_version}) ${var.instance_sizes.xs.instance_type}"
  ami_description              = var.ami_description
  instance_type                = var.instance_sizes.xs.instance_type
  region                       = var.build_in_region
  ami_regions                  = var.ami_regions
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
    volume_type           = var.instance_sizes.xs.data_volume_type
    volume_size           = var.instance_sizes.xs.data_volume_size
  }
  tags = var.ami_tags
}

source "amazon-ebs" "size-s" {
  ami_name                     = "Sourcegraph-S (v${var.instance_version}) ${var.instance_sizes.s.instance_type}"
  ami_description              = var.ami_description
  instance_type                = var.instance_sizes.s.instance_type
  region                       = var.build_in_region
  ami_regions                  = var.ami_regions
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
  tags = var.ami_tags
}

source "amazon-ebs" "size-m" {
  ami_name                     = "Sourcegraph-M (v${var.instance_version}) ${var.instance_sizes.m.instance_type}"
  ami_description              = var.ami_description
  instance_type                = var.instance_sizes.m.instance_type
  region                       = var.build_in_region
  ami_regions                  = var.ami_regions
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
    volume_type           = var.instance_sizes.m.data_volume_type
    volume_size           = var.instance_sizes.m.data_volume_size
  }
  tags = var.ami_tags
}

source "amazon-ebs" "size-l" {
  ami_name                     = "Sourcegraph-L (v${var.instance_version}) ${var.instance_sizes.l.instance_type}"
  ami_description              = var.ami_description
  instance_type                = var.instance_sizes.l.instance_type
  region                       = var.build_in_region
  ami_regions                  = var.ami_regions
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
    volume_type           = var.instance_sizes.l.data_volume_type
    volume_size           = var.instance_sizes.l.data_volume_size
  }
  tags = var.ami_tags
}

source "amazon-ebs" "size-xl" {
  ami_name                     = "Sourcegraph-XL (v${var.instance_version}) ${var.instance_sizes.xl.instance_type}"
  ami_description              = var.ami_description
  instance_type                = var.instance_sizes.xl.instance_type
  region                       = var.build_in_region
  ami_regions                  = var.ami_regions
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
  tags = var.ami_tags
}


build {
  name = "sourcegraph-amis"
  sources = [
    "source.amazon-ebs.size-xs",
    "source.amazon-ebs.size-s",
    "source.amazon-ebs.size-m",
    "source.amazon-ebs.size-l",
    "source.amazon-ebs.size-xl"
  ]
  provisioner "shell" {
    only             = ["amazon-ebs.size-xs"]
    environment_vars = ["INSTANCE_SIZE=XS", "INSTANCE_VERSION=${var.instance_version}"]
    scripts          = ["./install/install.sh"]
  }
  provisioner "shell" {
    only             = ["amazon-ebs.size-s"]
    environment_vars = ["INSTANCE_SIZE=S", "INSTANCE_VERSION=${var.instance_version}"]
    scripts          = ["./install/install.sh"]
  }
  provisioner "shell" {
    only             = ["amazon-ebs.size-m"]
    environment_vars = ["INSTANCE_SIZE=M", "INSTANCE_VERSION=${var.instance_version}"]
    scripts          = ["./install/install.sh"]
  }
  provisioner "shell" {
    only             = ["amazon-ebs.size-l"]
    environment_vars = ["INSTANCE_SIZE=L", "INSTANCE_VERSION=${var.instance_version}"]
    scripts          = ["./install/install.sh"]
  }
  provisioner "shell" {
    only             = ["amazon-ebs.size-xl"]
    environment_vars = ["INSTANCE_SIZE=XL", "INSTANCE_VERSION=${var.instance_version}"]
    scripts          = ["./install/install.sh"]
  }
}
