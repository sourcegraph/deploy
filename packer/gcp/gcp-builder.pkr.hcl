packer {
  required_plugins {
    googlecompute = {
      version = ">= 0.0.1"
      source = "github.com/hashicorp/googlecompute"
    }
  }
}

variable "dev" {
  type        = bool
  default     = true
}
variable "instance_version" {
  description = "Version number for the AMI build"
  type        = string
  default     = ""
}
variable "instance_sizes" {
  default               = {
    xs                  = {
      instance_type_gcp = "n2-standard-8"
    },
    s                   = {
      instance_type_gcp = "n2-standard-16"
    },
    m                   = {
      instance_type_gcp = "n2-standard-32"
    },
    l                   = {
      instance_type_gcp = "n2-standard-48"
    },
    xl                  = {
      instance_type_gcp = "n2-standard-64"
    }
  }
}
variable "location" {
  default                 = {
    gcp                   = {
      region              = "us-central1",
      zone                = "us-central1-a",
      destinations        = ["us"]
      destinations_dev    = ["us"]
    }
  }
}
variable "sources" {
  default                 = {
    dev                     = [ "source.googlecompute.dev" ]
    production              = [ "source.googlecompute.XS" ]
  }
}

locals {
  timestamp               = regex_replace(timestamp(), "[- TZ:]", "")
  build_date              = formatdate("YYYYMMDD", timestamp())
  image_version           = var.instance_version != "" ? replace(var.instance_version, ".", "") : "latest"
  gcp_regions             = var.dev ? var.location.gcp.destinations_dev : var.location.gcp.destinations
  source_group            = var.dev ? var.sources.dev : var.sources.production
}

source "googlecompute" "dev" {
  skip_create_image           = "${!var.dev}"
  project_id                  = "delivery-tiger-team"
  instance_name               = "sg-dev-${local.image_version}-${local.timestamp}"
  image_name                  = "sg-dev-${local.image_version}-${local.timestamp}"
  image_description           = "Sourcegraph Dev Compute Image ${local.image_version} - ${local.timestamp}"
  source_image                = "ubuntu-2204-jammy-v20221101a"
  ssh_username                = "sourcegraph"
  machine_type                = var.instance_sizes.xs.instance_type_gcp
  region                      = var.location.gcp.region
  zone                        = var.location.gcp.zone
  disk_size                   = 50
  disk_type                   = "pd-ssd"
  image_family                = "sourcegraph"
  image_storage_locations     = local.gcp_regions
  tags                        = ["sourcegraph", "dev"]
  image_labels                = { 
    version                   = local.image_version, 
    env                       = "dev", 
    team                      = "delivery" 
  }
}
source "googlecompute" "XS" {
  skip_create_image           = var.dev
  project_id                  = "sourcegraph-amis"
  instance_name               = "sourcegraph-${local.image_version}"
  image_name                  = "sourcegraph-aio-${local.image_version}"
  image_description           = "Sourcegraph Compute Image ${local.image_version} - ${formatdate("YYYYMMDD", timestamp())}"
  source_image                = "ubuntu-2204-jammy-v20221101a"
  ssh_username                = "sourcegraph"
  machine_type                = var.instance_sizes.xs.instance_type_gcp
  region                      = var.location.gcp.region
  zone                        = var.location.gcp.zone
  disk_size                   = 50
  disk_type                   = "pd-ssd"
  image_family                = "sourcegraph"
  image_storage_locations     = local.gcp_regions
  tags                        = ["sourcegraph", "production"]
  image_labels                = { 
    version                   = local.image_version, 
    env                       = "production", 
    team                      = "delivery" 
  }
}


build {
  name = "sourcegraph-amis"
  sources = local.source_group
  // Move the install.sh script to VM to run on next reboot 
  provisioner "file" {
    source = "./packer/gcp/install.sh"
    destination = "/home/sourcegraph/install.sh"
  }
  provisioner "shell" {
    only              = ["googlecompute.dev"]
    environment_vars  = ["INSTANCE_SIZE=XS", "INSTANCE_VERSION=${var.instance_version}"]
    scripts           = ["./packer/gcp/init.sh"]
  }
  provisioner "shell" {
    except            = ["googlecompute.dev"]
    environment_vars  = ["INSTANCE_SIZE=${upper(source.name)}", "INSTANCE_VERSION=${var.instance_version}"]
    scripts           = ["./packer/gcp/init.sh"]
  }
  post-processors{
    //  Post processors: mark images as public 
    post-processor "shell-local" {
      except              = ["googlecompute.dev"]
      inline              = [ 
        "gcloud compute images add-iam-policy-binding --project=sourcegraph-amis 'sourcegraph-aio-${local.image_version}' --member='allAuthenticatedUsers' --role='roles/compute.imageUser'",
      ]
    }
    post-processor "googlecompute-export" {
      except              = ["googlecompute.dev"]
      machine_type        = "n1-highcpu-16"
      disk_size           = 100
      disk_type           = "pd-ssd"
      paths               = ["gs://sourcegraph-images/latest/sourcegraph-aio-${local.image_version}.tar.gz"]
    }
  }
}