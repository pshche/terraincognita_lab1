# ============================================================================
# ФАЙЛ: terraform-module-lab/variables.tf
# ============================================================================

variable "zone" {
  description = "Зона доступности"
  type        = string
  default     = "ru-central1-a"
}

variable "name_prefix" {
  description = "Уникальный префикс для имён ресурсов"
  type        = string
  default     = "terron"
}

variable "vm_names" {
  description = "Имена виртуальных машин"
  type = object({
    web = string
    api = string
  })
  default = {
    web = "web"
    api = "api"
  }
}

variable "extra_disk_names" {
  description = "Список имён дополнительных дисков для ВМ api"
  type        = list(string)
  default     = ["logs", "backup"]
}

variable "extra_disk_type" {
  description = "Тип дополнительных дисков"
  type        = string
  default     = "network-hdd"

  validation {
    condition     = contains(["network-hdd", "network-ssd"], var.extra_disk_type)
    error_message = "Тип диска должен быть network-hdd или network-ssd."
  }
}

variable "extra_disk_size" {
  description = "Размер дополнительных дисков в ГБ"
  type        = number
  default     = 8

  validation {
    condition     = var.extra_disk_size > 1
    error_message = "Размер диска должен быть больше 1 ГБ."
  }
}

variable "vm_specification" {
  description = "Параметры виртуальных машин web и api"
  type = map(object({
    cores     = number
    memory    = number
    core_fraction = number
    disk_size = number
    boot_disk = string
  }))

  default = {
    web = {
      cores     = 2
      memory    = 2
      core_fraction = 20 # ← дешевле
      disk_size = 8
      boot_disk = "fd845dr9j4h2aaq1m6ko"
    }
    api = {
      cores     = 2
      memory    = 2
      core_fraction = 20 # ← дешевле
      disk_size = 8
      boot_disk = "fd845dr9j4h2aaq1m6ko"
    }
  }

  validation {
    condition = alltrue([
      for vm in values(var.vm_specification) : contains([2], vm.cores)
    ])
    error_message = "Значение cores должно быть 2."
  }

  validation {
    condition = alltrue([
      for vm in values(var.vm_specification) : contains([2, 4], vm.memory)
    ])
    error_message = "Значение memory должно быть 2 или 4."
  }

  validation {
    condition = alltrue([
      for vm in values(var.vm_specification) : vm.disk_size > 1
    ])
    error_message = "Значение disk_size должно быть больше 1."
  }
}

variable "ssh_public_key" {
  description = "Публичный SSH-ключ для доступа к ВМ"
  type        = string
}

