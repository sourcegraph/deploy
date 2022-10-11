packer {
  required_plugins {
    amazon = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/amazon"
    }
    googlecompute = {
      version = ">= 0.0.1"
      source = "github.com/hashicorp/googlecompute"
    }
  }
}

variable "instance_version" {
  description = "Version number for the AMI build"
  type        = string
  default     = "4.0.1"
}

variable "instance_sizes" {
  type = object({
    xs = object({
      instance_type_gcp    = string
    })
    s = object({
      instance_type_gcp    = string
    })
    m = object({
      instance_type_gcp    = string
    })
    l = object({
      instance_type_gcp    = string
    })
    xl = object({
      instance_type_gcp    = string
    })
  })
  default = { 
    xs = {
        instance_type_gcp = "n2-standard-8"
    },
    s = {
        instance_type_gcp = "n2-standard-16"
    },
    m = {
        instance_type_gcp = "n2-standard-32"
    },
    l = {
        instance_type_gcp = "n2-standard-48"
    },
    xl = {
        instance_type_gcp = "n2-standard-64"
    }
  }
}

variable "location" {
  default           = {
    gcp             = {
      region        = "us-central1",
      zone          = "us-central1-a",
      destinations  = ["us"]
      // destinations  = ["us", "asia", "europe"]
    }
  }
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  image_version = replace(var.instance_version, ".", "")
}

source "googlecompute" "dev" {
  project_id                  = "delivery-tiger-team"
  // project_id                  = "sourcegraph-amis"
  instance_name               = "dev-xs-v${local.image_version}-${local.timestamp}"
  image_name                  = "dev-xs-v${local.image_version}-${local.timestamp}"
  image_description           = "Dev GCP AMI v${local.image_version} - ${formatdate("YYYYMMDD", timestamp())}"
  source_image                = "ubuntu-1804-bionic-v20221005"
  ssh_username                = "sourcegraph"
  machine_type                = var.instance_sizes.xs.instance_type_gcp
  region                      = var.location.gcp.region
  zone                        = var.location.gcp.zone
  disk_size                   = 50
  disk_type                   = "pd-ssd"
  image_storage_locations     = var.location.gcp.destinations
  tags                        = ["ami"]
  image_labels                = { version = local.image_version }
}

source "googlecompute" "size-xs" {
  project_id                  = "sourcegraph-amis"
  instance_name               = "sourcegraph-xs-v${local.image_version}"
  image_name                  = "sourcegraph-xs-v${local.image_version}"
  image_description           = "Sourcegraph GCP AMI v${local.image_version} - ${formatdate("YYYYMMDD", timestamp())}"
  source_image                = "ubuntu-1804-bionic-v20221005"
  ssh_username                = "sourcegraph"
  machine_type                = var.instance_sizes.xs.instance_type_gcp
  region                      = var.location.gcp.region
  zone                        = var.location.gcp.zone
  disk_size                   = 50
  disk_type                   = "pd-ssd"
  image_storage_locations     = var.location.gcp.destinations
  tags                        = ["ami"]
  image_labels                = { version = local.image_version }
}

source "googlecompute" "size-s" {
  project_id                  = "sourcegraph-amis"
  instance_name               = "sourcegraph-s-v${local.image_version}"
  image_name                  = "sourcegraph-s-v${local.image_version}"
  image_description           = "Sourcegraph GCP AMI v${local.image_version} - ${formatdate("YYYYMMDD", timestamp())}"
  source_image                = "ubuntu-1804-bionic-v20221005"
  ssh_username                = "sourcegraph"
  machine_type                = var.instance_sizes.s.instance_type_gcp
  region                      = var.location.gcp.region
  zone                        = var.location.gcp.zone
  disk_size                   = 50
  disk_type                   = "pd-ssd"
  image_storage_locations     = var.location.gcp.destinations
  tags                        = ["ami"]
  image_labels                = { version = local.image_version }
}

source "googlecompute" "size-m" {
  project_id                  = "sourcegraph-amis"
  instance_name               = "sourcegraph-m-v${local.image_version}"
  image_name                  = "sourcegraph-m-v${local.image_version}"
  image_description           = "Sourcegraph GCP AMI v${local.image_version} - ${formatdate("YYYYMMDD", timestamp())}"
  source_image                = "ubuntu-1804-bionic-v20221005"
  ssh_username                = "sourcegraph"
  machine_type                = var.instance_sizes.m.instance_type_gcp
  region                      = var.location.gcp.region
  zone                        = var.location.gcp.zone
  disk_size                   = 50
  disk_type                   = "pd-ssd"
  image_storage_locations     = var.location.gcp.destinations
  tags                        = ["ami"]
  image_labels                = { version = local.image_version }
}

source "googlecompute" "size-l" {
  project_id                  = "sourcegraph-amis"
  instance_name               = "sourcegraph-l-v${local.image_version}"
  image_name                  = "sourcegraph-l-v${local.image_version}"
  image_description           = "Sourcegraph GCP AMI v${local.image_version} - ${formatdate("YYYYMMDD", timestamp())}"
  source_image                = "ubuntu-1804-bionic-v20221005"
  ssh_username                = "sourcegraph"
  machine_type                = var.instance_sizes.l.instance_type_gcp
  region                      = var.location.gcp.region
  zone                        = var.location.gcp.zone
  disk_size                   = 50
  disk_type                   = "pd-ssd"
  image_storage_locations     = var.location.gcp.destinations
  tags                        = ["ami"]
  image_labels                = { version = local.image_version }
}

source "googlecompute" "size-xl" {
  project_id                  = "sourcegraph-amis"
  instance_name               = "sourcegraph-xl-v${local.image_version}"
  image_name                  = "sourcegraph-xl-v${local.image_version}"
  image_description           = "Sourcegraph GCP AMI v${local.image_version} - ${formatdate("YYYYMMDD", timestamp())}"
  source_image                = "ubuntu-1804-bionic-v20221005"
  ssh_username                = "sourcegraph"
  machine_type                = var.instance_sizes.xl.instance_type_gcp
  region                      = var.location.gcp.region
  zone                        = var.location.gcp.zone
  disk_size                   = 50
  disk_type                   = "pd-ssd"
  image_storage_locations     = var.location.gcp.destinations
  tags                        = ["ami"]
  image_labels                = { version = local.image_version }
}

build {
  name = "sourcegraph-amis"
  sources = [
    "source.googlecompute.dev",
    // "source.googlecompute.size-xs",
    // "source.googlecompute.size-s",
    // "source.googlecompute.size-m",
    // "source.googlecompute.size-l",
    // "source.googlecompute.size-xl",
  ]
  provisioner "file" {
    source = "./ami/packer/gcp/install.sh"
    destination = "/home/sourcegraph/install.sh"
  }
  provisioner "shell" {
    only             = ["googlecompute.dev"]
    environment_vars = ["INSTANCE_SIZE=XS", "INSTANCE_VERSION=${var.instance_version}"]
    scripts          = ["./ami/packer/gcp/init.sh"]
  }
  provisioner "shell" {
    only             = ["googlecompute.size-xs"]
    environment_vars = ["INSTANCE_SIZE=XS", "INSTANCE_VERSION=${var.instance_version}"]
    scripts          = ["./ami/packer/gcp/init.sh"]
  }
  provisioner "shell" {
    only             = ["googlecompute.size-s"]
    environment_vars = ["INSTANCE_SIZE=S", "INSTANCE_VERSION=${var.instance_version}"]
    scripts          = ["./ami/packer/gcp/init.sh"]
  }
  provisioner "shell" {
    only             = ["googlecompute.size-m"]
    environment_vars = ["INSTANCE_SIZE=M", "INSTANCE_VERSION=${var.instance_version}"]
    scripts          = ["./ami/packer/gcp/init.sh"]
  }
  provisioner "shell" {
    only             = ["googlecompute.size-l"]
    environment_vars = ["INSTANCE_SIZE=L", "INSTANCE_VERSION=${var.instance_version}"]
    scripts          = ["./ami/packer/gcp/init.sh"]
  }
  provisioner "shell" {
    only             = ["googlecompute.size-xl"]
    environment_vars = ["INSTANCE_SIZE=XL", "INSTANCE_VERSION=${var.instance_version}"]
    scripts          = ["./ami/packer/gcp/init.sh"]
  }
}
