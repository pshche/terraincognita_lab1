# ============================================================================
# ФАЙЛ: terraform-module-lab/main.tf
# ============================================================================
terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.100"
    }
  }
  required_version = ">= 1.5.0"

  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    bucket               = "msa-terraform"
    region               = "ru-central1"
    key                  = "terraform.tfstate"
    workspace_key_prefix = "state" # Изолирует state для dev и prod

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    skip_metadata_api_check     = true
  }
}

provider "yandex" {
  zone = var.zone
}

module "disks" {
  source = "./modules/disks"

  disk_names = var.extra_disk_names
  disk_type  = var.extra_disk_type
  disk_size  = var.extra_disk_size
  zone       = var.zone
}

module "vms" {
  source = "./modules/vms"

  vm_specification = var.vm_specification
  ssh_public_key   = var.ssh_public_key
  zone             = var.zone
  vm_names         = var.vm_names
  extra_disk_ids   = values(module.disks.disk_ids)
}