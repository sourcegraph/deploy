packer {
  required_plugins {
    azure = {
      version = ">= 1.3.1"
      source  = "github.com/hashicorp/azure"
    }
  }
}

variable "dev" {
  type    = bool
  default = true
}

variable "instance_version" {
  description = "Version number for the image build"
  type        = string
}

variable "image_regions_azr" {
  description = "Regions to copy the images to"
  type        = list(string)
  default     = ["Central US"]
}

variable "instance_sizes" {
  type = object({
    xs = object({
      instance_type    = string
      data_volume_type = string
      data_volume_size = list(number)
    })
    s = object({
      instance_type    = string
      data_volume_type = string
      data_volume_size = list(number)
    })
    m = object({
      instance_type    = string
      data_volume_type = string
      data_volume_size = list(number)
    })
    l = object({
      instance_type    = string
      data_volume_type = string
      data_volume_size = list(number)
    })
    xl = object({
      instance_type    = string
      data_volume_type = string
      data_volume_size = list(number)
    })
  })
  default = {
    xs = {
      instance_type    = "Standard_D8as_v5" # 8/32
      data_volume_type = "Standard_LRS"
      data_volume_size = [500]
    },
    s = {
      instance_type    = "Standard_D16as_v5" # 16/64
      data_volume_type = "Standard_LRS"
      data_volume_size = [500]
    },
    m = {
      instance_type    = "Standard_D32as_v5" # 32/128
      data_volume_type = "Standard_LRS"
      data_volume_size = [500]
    },
    l = {
      instance_type    = "Standard_D48as_v5" # 48/192
      data_volume_type = "Premium_LRS"
      data_volume_size = [500]
    },
    xl = {
      instance_type    = "Standard_D96as_v5" # 96/384
      data_volume_type = "Premium_LRS"
      data_volume_size = [500]
    }
  }
}

variable "build_in_region" {
  description = "Region used by packer to build the image"
  type        = string
  default     = "Central US"
}

variable "image_regions" {
  description = "Region to copy the images to"
  default = {
    dev = ["Central US"],
    production = [
      "Central US",
      "East US",
      "East US 2",
      "North Central US",
      "South Central US",
      "West US",
      "West US 2",
      "West US 3",
    ]
  }
}

locals {
  regions = var.dev ? var.image_regions.dev : var.image_regions.production
}

source "azure-arm" "xs" {
  use_azure_cli_auth = true

  os_type         = "Linux"
  image_offer     = "debian-11"
  image_publisher = "Debian"
  image_sku       = "11"

  ssh_username = "sourcegraph"

  vm_size = var.instance_sizes.xs.instance_type

  managed_image_name                 = "sourcegraph-xs-v${var.instance_version}"
  managed_image_resource_group_name  = "sourcegraph"
  managed_image_storage_account_type = var.instance_sizes.xs.data_volume_type

  build_resource_group_name = "sourcegraph"

  os_disk_size_gb      = 50
  disk_additional_size = var.instance_sizes.xs.data_volume_size
  disk_caching_type    = "ReadWrite"
}

source "azure-arm" "s" {
  use_azure_cli_auth = true

  os_type         = "Linux"
  image_offer     = "debian-11"
  image_publisher = "Debian"
  image_sku       = "11"

  ssh_username = "sourcegraph"

  vm_size = var.instance_sizes.s.instance_type

  managed_image_name                 = "sourcegraph-s-v${var.instance_version}"
  managed_image_resource_group_name  = "sourcegraph"
  managed_image_storage_account_type = var.instance_sizes.s.data_volume_type

  build_resource_group_name = "sourcegraph"

  os_disk_size_gb      = 50
  disk_additional_size = var.instance_sizes.s.data_volume_size
  disk_caching_type    = "ReadWrite"
}

source "azure-arm" "m" {
  use_azure_cli_auth = true

  os_type         = "Linux"
  image_offer     = "debian-11"
  image_publisher = "Debian"
  image_sku       = "11"

  ssh_username = "sourcegraph"

  vm_size = var.instance_sizes.m.instance_type

  managed_image_name                 = "sourcegraph-m-v${var.instance_version}"
  managed_image_resource_group_name  = "sourcegraph"
  managed_image_storage_account_type = var.instance_sizes.m.data_volume_type

  build_resource_group_name = "sourcegraph"

  os_disk_size_gb      = 50
  disk_additional_size = var.instance_sizes.m.data_volume_size
  disk_caching_type    = "ReadWrite"
}

source "azure-arm" "l" {
  use_azure_cli_auth = true

  os_type         = "Linux"
  image_offer     = "debian-11"
  image_publisher = "Debian"
  image_sku       = "11"

  ssh_username = "sourcegraph"

  vm_size = var.instance_sizes.l.instance_type

  managed_image_name                 = "sourcegraph-l-v${var.instance_version}"
  managed_image_resource_group_name  = "sourcegraph"
  managed_image_storage_account_type = var.instance_sizes.l.data_volume_type

  build_resource_group_name = "sourcegraph"

  os_disk_size_gb      = 50
  disk_additional_size = var.instance_sizes.l.data_volume_size
  disk_caching_type    = "ReadWrite"
}

source "azure-arm" "xl" {
  use_azure_cli_auth = true

  os_type         = "Linux"
  image_offer     = "debian-11"
  image_publisher = "Debian"
  image_sku       = "11"

  ssh_username = "sourcegraph"

  vm_size = var.instance_sizes.xl.instance_type

  managed_image_name                 = "sourcegraph-xl-v${var.instance_version}"
  managed_image_resource_group_name  = "sourcegraph"
  managed_image_storage_account_type = var.instance_sizes.xl.data_volume_type

  build_resource_group_name = "sourcegraph"

  os_disk_size_gb      = 50
  disk_additional_size = var.instance_sizes.xl.data_volume_size
  disk_caching_type    = "ReadWrite"
}

build {
  name = "sourcegraph-images"
  sources = [
    "source.azure-arm.xs",
    "source.azure-arm.s",
    "source.azure-arm.m",
    "source.azure-arm.l",
    "source.azure-arm.xl"
  ]
  provisioner "shell" {
    scripts           = ["./packer/azr/cgroup.sh"]
    expect_disconnect = true
  }
  provisioner "file" {
    sources     = ["./packer/azr/reboot.sh", "./install/ingress.yaml", "./install/prometheus-override.ConfigMap.yaml"]
    destination = "/tmp/"
  }
  provisioner "file" {
    source      = "./install/override.${upper(source.name)}.yaml"
    destination = "/tmp/override.yaml"
  }
  provisioner "shell" {
    environment_vars = ["INSTANCE_SIZE=${upper(source.name)}", "INSTANCE_VERSION=${var.instance_version}"]
    scripts          = ["./packer/azr/install.sh"]
  }
}
