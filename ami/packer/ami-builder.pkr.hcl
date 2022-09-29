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
    type    = string
}
variable "instance_sizes" {
    type    = object({
        xs   = object({
            instance_type = string
            data_volume_type = string
            data_volume_size = string
        })
        s = object({
            instance_type = string
            data_volume_type = string
            data_volume_size = string
        })
        m = object({
            instance_type = string
            data_volume_type = string
            data_volume_size = string
        })
        l = object({
            instance_type = string
            data_volume_type = string
            data_volume_size = string
        })
        xl = object({
            instance_type = string
            data_volume_type = string
            data_volume_size = string
        })
    })
}
variable "ami_description" {
    type    = string
    default = "Sourcegraph AMI"
}
variable "build_in_region" {
    description = "Region to build the launch instances"
    type = string
    default = "us-west-2"
}
variable "ami_regions" {
    description = "Region to copy the AMIs to"
    type = list(string)
}
data "amazon-linux" "filters" {
    filters = {
        name                               = "amzn2-ami-kernel-*-hvm-*-x86_64-gp2"
        architecture                       = "x86_64"
        root-device-type                   = "ebs"
        virtualization-type                = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
    region      = var.ami_region
}
data "amazon-subnet" "filters" {
    filters = {
        "tag:Name" : "packer-build"
    }
    most_free = true
    random    = false
}
data "amazon-ebs-volume" "root" {
    delete_on_termination = true
    device_name           = "/dev/xvda"
    encrypted             = false
    volume_type = "gp3"
    volume_size = 50
}
data "ami-tags" "general" {
    Name = "production"
    Version = var.instance_version
}
source "amazon-ebs" "size-xs" {
    ami_name                    = "sourcegraph-XS (v${instance_version}) ${var.instance_sizes.xs.instance_type}"
    ami_description             = var.ami_description
    instance_type               = var.instance_sizes.xs.instance_type
    region                      = var.build_in_region
    ami_regions                 = var.ami_regions
    associate_public_ip_address = true
    source_ami                  = data.amazon-linux.filters.id
    subnet_filter               = data.amazon-subnet.filters.id
    ssh_username                = "ec2-user"
    launch_block_device_mappings = data.amazon-ebs-volume.root.id
    launch_block_device_mappings {
        device_name = "/dev/sdb"
        encrypted   = false
        delete_on_termination = false
        volume_type = var.instance_sizes.xs.data_volume_type
        volume_size = var.instance_sizes.xs.data_volume_size
    }
}
source "amazon-ebs" "size-s" {
    ami_name                    = "sourcegraph-S (v${instance_version}) ${var.instance_sizes.s.instance_type}"
    ami_description             = var.ami_description
    instance_type               = var.instance_sizes.s.instance_type
    region                      = var.build_in_region
    ami_regions                 = var.ami_regions
    associate_public_ip_address = true
    source_ami                  = data.amazon-linux.filters.id
    subnet_filter               = data.amazon-subnet.filters.id
    ssh_username                = "ec2-user"
    launch_block_device_mappings = data.amazon-ebs-volume.root.id
    launch_block_device_mappings {
        device_name = "/dev/sdb"
        encrypted   = false
        delete_on_termination = false
        volume_type = var.instance_sizes.s.data_volume_type
        volume_size = var.instance_sizes.s.data_volume_size
    }
}
source "amazon-ebs" "size-l" {
    ami_name                    = "sourcegraph-L (v${instance_version}) ${var.instance_sizes.l.instance_type}"
    ami_description             = var.ami_description
    instance_type               = var.instance_sizes.l.instance_type
    region                      = var.build_in_region
    ami_regions                 = var.ami_regions
    associate_public_ip_address = true
    source_ami                  = data.amazon-linux.filters.id
    subnet_filter               = data.amazon-subnet.filters.id
    ssh_username                = "ec2-user"
    launch_block_device_mappings = data.amazon-ebs-volume.root.id
    launch_block_device_mappings {
        device_name = "/dev/sdb"
        encrypted   = false
        delete_on_termination = false
        volume_type = var.instance_sizes.l.data_volume_type
        volume_size = var.instance_sizes.l.data_volume_size
    }
}
source "amazon-ebs" "size-xl" {
    ami_name                    = "sourcegraph-L (v${instance_version}) ${var.instance_sizes.xl.instance_type}"
    ami_description             = var.ami_description
    instance_type               = var.instance_sizes.xl.instance_type
    region                      = var.build_in_region
    ami_regions                 = var.ami_regions
    associate_public_ip_address = true
    source_ami                  = data.amazon-linux.filters.id
    subnet_filter               = data.amazon-subnet.filters.id
    ssh_username                = "ec2-user"
    launch_block_device_mappings = data.amazon-ebs-volume.root.id
    launch_block_device_mappings {
        device_name = "/dev/sdb"
        encrypted   = false
        delete_on_termination = false
        volume_type = var.instance_sizes.xl.data_volume_type
        volume_size = var.instance_sizes.xl.data_volume_size
    }
}
build {
    name    = "sourcegraph-amis"
    sources = [
        "source.amazon-ebs.size-xs",
        "source.amazon-ebs.size-l"
        "source.amazon-ebs.size-xl"
    ]
    provisioner "shell" {
        only = ["amazon-ebs.size-xs"]
        environment_vars = ["INSTANCE_SIZE=XS", "INSTANCE_VERSION=${var.instance_version}"]
        scripts = ["../launch.sh"]
    }
    provisioner "shell" {
        only = ["amazon-ebs.size-s"]
        environment_vars = ["INSTANCE_SIZE=S", "INSTANCE_VERSION=${var.instance_version}"]
        scripts = ["../launch.sh"]
    }
    provisioner "shell" {
        only = ["amazon-ebs.size-m"]
        environment_vars = ["INSTANCE_SIZE=M", "INSTANCE_VERSION=${var.instance_version}"]
        scripts = ["../launch.sh"]
    }
    provisioner "shell" {
        only = ["amazon-ebs.size-l"]
        environment_vars = ["INSTANCE_SIZE=L", "INSTANCE_VERSION=${var.instance_version}"]
        scripts = ["../launch.sh"]
    }
    provisioner "shell" {
        only = ["amazon-ebs.size-xl"]
        environment_vars = ["INSTANCE_SIZE=XL", "INSTANCE_VERSION=${var.instance_version}"]
        scripts = ["../launch.sh"]
    }
}
