# ============================================================================
# ФАЙЛ: terraform-module-lab/outputs.tf
# РОЛЬ: выходные значения корневого модуля. Проксируют outputs
#       дочерних модулей, чтобы их было видно после apply.
# ЧТО ПРОКСИРУЕТ:
#   - disk_ids    ← modules/disks/outputs.tf
#   - private_ips ← modules/vms/outputs.tf
# ============================================================================

# Map {имя_диска → ID} для всех дополнительных дисков.
# Проксирует output из модуля disks.
# См. modules/disks/outputs.tf → disk_ids.
output "disk_ids" {
  description = "Map с ID всех созданных дополнительных дисков"
  value       = module.disks.disk_ids
}

# Map {web_vm/api_vm → внутренний_IP} для обеих ВМ.
# Проксирует output из модуля vms.
# См. modules/vms/outputs.tf → private_ips.
output "private_ips" {
  description = "Внутренние IP-адреса ВМ web и api"
  value       = module.vms.private_ips
}