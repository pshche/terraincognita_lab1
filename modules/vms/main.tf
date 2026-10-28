# ============================================================================
# ФАЙЛ: terraform-module-lab/modules/vms/main.tf
# ============================================================================

# Читаем существующую подсеть (как требует задание)
data "yandex_vpc_subnet" "default_subnet" {
  name = "default-ru-central1-a"
}

resource "yandex_compute_instance" "web" {
  name = var.vm_names.web
  zone = var.zone # Явно задаём зону

  resources {
    cores         = var.vm_specification["web"].cores
    memory        = var.vm_specification["web"].memory
    core_fraction = var.vm_specification["web"].core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = var.vm_specification["web"].boot_disk
      size     = var.vm_specification["web"].disk_size
    }
  }

  network_interface {
    subnet_id = data.yandex_vpc_subnet.default_subnet.id
    nat       = false
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }

  allow_stopping_for_update = true
}

resource "yandex_compute_instance" "api" {
  name = var.vm_names.api
  zone = var.zone # Явно задаём зону

  resources {
    cores         = var.vm_specification["api"].cores
    memory        = var.vm_specification["api"].memory
    core_fraction = var.vm_specification["api"].core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = var.vm_specification["api"].boot_disk
      size     = var.vm_specification["api"].disk_size
    }
  }

  network_interface {
    subnet_id = data.yandex_vpc_subnet.default_subnet.id
    nat       = false
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }

  allow_stopping_for_update = true

  dynamic "secondary_disk" {
    for_each = var.extra_disk_ids
    content {
      disk_id     = secondary_disk.value
      auto_delete = false
    }
  }
}