# ============================================================================
# ФАЙЛ: terraform-module-lab/main.tf
# РОЛЬ: сборка модуля. Здесь вызываются три дочерних модуля:
#       disks, network, vms.
# ============================================================================

provider "yandex" {
  zone = var.zone
}

# ============================================================================
# Вызов дочернего модуля №1: диски.
# ============================================================================
module "disks" {
  source = "./modules/disks"

  disk_names = var.extra_disk_names
  disk_type  = var.extra_disk_type
  disk_size  = var.extra_disk_size
  zone       = var.zone
}

# ============================================================================
# Вызов дочернего модуля №2: сеть и подсеть.
# ============================================================================
module "network" {
  source = "./modules/network"

  zone         = var.zone
  network_name = "lesson-terraform-network-${var.name_prefix}"
  subnet_name  = "lesson-terraform-subnet-${var.name_prefix}"
  subnet_cidr  = "10.128.0.0/24"
}

# ============================================================================
# Вызов дочернего модуля №3: виртуальные машины.
# ============================================================================
module "vms" {
  source = "./modules/vms"

  vm_specification = var.vm_specification
  ssh_public_key   = var.ssh_public_key
  zone             = var.zone
  vm_names         = var.vm_names
  subnet_id        = module.network.subnet_id
  extra_disk_ids   = values(module.disks.disk_ids)
}