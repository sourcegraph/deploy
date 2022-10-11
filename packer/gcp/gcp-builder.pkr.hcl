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

variable "dev" {
  type        = bool
  default     = true
}
variable "instance_version" {
  description = "Version number for the AMI build"
  type        = string
  default     = "4.0.0"
}
variable "instance_sizes" {
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
  default                 = {
    gcp                   = {
      region              = "us-central1",
      zone                = "us-central1-a",
      destinations        = ["us"]
      destinations_dev    = ["us"]
    }
  }
}

locals {
  timestamp               = regex_replace(timestamp(), "[- TZ:]", "")
  build_date              = formatdate("YYYYMMDD", timestamp())
  image_version           = replace(var.instance_version, ".", "")
  gcp_regions             = "${ var.dev ? var.location.gcp.destinations_dev : var.location.gcp.destinations}"
}

source "googlecompute" "dev" {
  skip_create_image           = "${!var.dev}"
  project_id                  = "delivery-tiger-team"
  instance_name               = "dev-v${local.image_version}-${local.timestamp}"
  image_name                  = "dev-v${local.image_version}-${local.timestamp}"
  image_description           = "Dev Compute Image v${local.image_version} - ${local.timestamp}"
  source_image                = "ubuntu-1804-bionic-v20221005"
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
  instance_name               = "sourcegraph-xs-v${local.image_version}"
  image_name                  = "sourcegraph-xs-v${local.image_version}"
  image_description           = "Sourcegraph Compute Image v${local.image_version} - ${formatdate("YYYYMMDD", timestamp())}"
  source_image                = "ubuntu-1804-bionic-v20221005"
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
source "googlecompute" "S" {
  skip_create_image           = var.dev
  project_id                  = "sourcegraph-amis"
  instance_name               = "sourcegraph-s-v${local.image_version}"
  image_name                  = "sourcegraph-s-v${local.image_version}"
  image_description           = "Sourcegraph Compute Image v${local.image_version} - ${formatdate("YYYYMMDD", timestamp())}"
  source_image                = "ubuntu-1804-bionic-v20221005"
  ssh_username                = "sourcegraph"
  machine_type                = var.instance_sizes.s.instance_type_gcp
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
source "googlecompute" "M" {
  skip_create_image           = var.dev
  project_id                  = "sourcegraph-amis"
  instance_name               = "sourcegraph-m-v${local.image_version}"
  image_name                  = "sourcegraph-m-v${local.image_version}"
  image_description           = "Sourcegraph Compute Image v${local.image_version} - ${formatdate("YYYYMMDD", timestamp())}"
  source_image                = "ubuntu-1804-bionic-v20221005"
  ssh_username                = "sourcegraph"
  machine_type                = var.instance_sizes.m.instance_type_gcp
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
source "googlecompute" "L" {
  skip_create_image           = var.dev
  project_id                  = "sourcegraph-amis"
  instance_name               = "sourcegraph-l-v${local.image_version}"
  image_name                  = "sourcegraph-l-v${local.image_version}"
  image_description           = "Sourcegraph Compute Image v${local.image_version} - ${formatdate("YYYYMMDD", timestamp())}"
  source_image                = "ubuntu-1804-bionic-v20221005"
  ssh_username                = "sourcegraph"
  machine_type                = var.instance_sizes.l.instance_type_gcp
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
source "googlecompute" "XL" {
  skip_create_image           = var.dev
  project_id                  = "sourcegraph-amis"
  instance_name               = "sourcegraph-xl-v${local.image_version}"
  image_name                  = "sourcegraph-xl-v${local.image_version}"
  image_description           = "Sourcegraph Compute Image v${local.image_version} - ${formatdate("YYYYMMDD", timestamp())}"
  source_image                = "ubuntu-1804-bionic-v20221005"
  ssh_username                = "sourcegraph"
  machine_type                = var.instance_sizes.xl.instance_type_gcp
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
  sources = [
    "source.googlecompute.dev",
    "source.googlecompute.XS",
    "source.googlecompute.S",
    "source.googlecompute.M",
    "source.googlecompute.L",
    "source.googlecompute.XL",
  ]
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
  //  Post processors: export the image as a gzipped tarball locally, and mark images as public 
  post-processors{
    post-processor "compress" {
      output                = ".ami-output/${source.name}.tar.gz"
      keep_input_artifact   = true
    }
    post-processor "shell-local" {
      except                  = ["googlecompute.dev"]
      inline                = [ 
        "gcloud compute images add-iam-policy-binding --project=sourcegraph-amis 'sourcegraph-${lower(source.name)}-v${local.image_version}' --member='allAuthenticatedUsers' --role='roles/compute.imageUser'",
      ]
    }
  }
}