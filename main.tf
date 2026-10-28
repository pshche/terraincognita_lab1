# ============================================================================
# ФАЙЛ: terraform-module-lab/main.tf
# ============================================================================

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