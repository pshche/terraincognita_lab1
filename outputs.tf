# ============================================================================
# ФАЙЛ: terraform-module-lab/outputs.tf
# ============================================================================

output "disk_ids" {
  description = "Map с ID всех созданных дополнительных дисков"
  value       = module.disks.disk_ids
}

output "private_ips" {
  description = "Внутренние IP-адреса ВМ web и api"
  value       = module.vms.private_ips
}