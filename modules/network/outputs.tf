# ============================================================================
# ФАЙЛ: terraform-module-lab/modules/network/outputs.tf
# РОЛЬ: отдаёт наружу ID сети и подсети.
# ПОТРЕБИТЕЛИ:
#   - terraform-module-lab/main.tf → module "vms" { subnet_id = ... }
# ============================================================================

output "network_id" {
  description = "ID созданной сети"
  value       = yandex_vpc_network.this.id
}

output "subnet_id" {
  description = "ID созданной подсети"
  value       = yandex_vpc_subnet.this.id
}