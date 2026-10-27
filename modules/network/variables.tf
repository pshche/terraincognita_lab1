# ============================================================================
# ФАЙЛ: terraform-module-lab/modules/network/variables.tf
# РОЛЬ: входные переменные модуля network.
# ============================================================================

variable "zone" {
  description = "Зона доступности для подсети"
  type        = string
}

variable "network_name" {
  description = "Имя создаваемой сети"
  type        = string
}

variable "subnet_name" {
  description = "Имя создаваемой подсети"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR-диапазон подсети"
  type        = string
  default     = "10.128.0.0/24"
}