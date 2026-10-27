# ============================================================================
# ФАЙЛ: terraform-module-lab/modules/vms/outputs.tf
# РОЛЬ: отдаёт внутренние IP-адреса ВМ в формате map.
# ПОТРЕБИТЕЛИ:
#   - terraform-module-lab/main.tf → output "private_ips" (проксирует)
# ============================================================================

output "private_ips" {
  description = "Внутренние IP-адреса ВМ web и api"

  # Ресурсы web/api созданы в modules/vms/main.tf.
  # Обращаемся к полю ip_address первого сетевого интерфейса каждой ВМ.
  # Ключи названы web_vm/api_vm для наглядности в выводе.
  value = {
    web_vm = yandex_compute_instance.web.network_interface[0].ip_address
    api_vm = yandex_compute_instance.api.network_interface[0].ip_address
  }
}