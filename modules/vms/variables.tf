# ============================================================================
# ФАЙЛ: terraform-module-lab/modules/vms/variables.tf
# ============================================================================

variable "vm_specification" {
  description = "Параметры ВМ"
  type = map(object({
    cores         = number
    memory        = number
    core_fraction = optional(number, 20)
    disk_size     = number
    boot_disk     = string
  }))
}

variable "ssh_public_key" {
  description = "Публичный SSH-ключ"
  type        = string
}

variable "extra_disk_ids" {
  description = "Список ID дополнительных дисков для ВМ api"
  type        = list(string)
  default     = []
}

variable "zone" {
  description = "Зона доступности"
  type        = string
}

variable "vm_names" {
  description = "Имена виртуальных машин"
  type = object({
    web = string
    api = string
  })
}