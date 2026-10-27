# ============================================================================
# ФАЙЛ: terraform-module-lab/modules/disks/variables.tf
# РОЛЬ: объявление входных переменных модуля disks.
# ЗНАЧЕНИЯ приходят из:
#   - terraform-module-lab/main.tf → module "disks" { ... }
# ИСПОЛЬЗУЮТСЯ в:
#   - terraform-module-lab/modules/disks/main.tf
# ============================================================================

# Список имён дисков для создания.
variable "disk_names" {
  description = "Список имён дисков"
  type        = list(string)
}

# Тип создаваемых дисков (network-hdd / network-ssd).
variable "disk_type" {
  description = "Тип диска"
  type        = string
}

# Размер каждого диска в ГБ.
variable "disk_size" {
  description = "Размер диска в ГБ"
  type        = number
}

# Зона доступности — должна совпадать с зоной ВМ, к которой подключается диск.
variable "zone" {
  description = "Зона доступности"
  type        = string
}