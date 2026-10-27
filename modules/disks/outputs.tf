# ============================================================================
# ФАЙЛ: terraform-module-lab/modules/disks/outputs.tf
# РОЛЬ: отдаёт наружу map {имя_диска → ID} для всех созданных дисков.
# ПОТРЕБИТЕЛИ:
#   - terraform-module-lab/main.tf → output "disk_ids" (проксирует)
#   - terraform-module-lab/main.tf → module "vms" { extra_disk_ids = ... }
# ============================================================================

output "disk_ids" {
  description = "Map {имя_диска → ID} созданных дополнительных дисков"

  # for-выражение обходит map yandex_compute_disk.extra_disks
  # (создан в modules/disks/main.tf) и собирает map {ключ → ID}.
  # Ключ — имя диска (each.key), значение — ID.
  value = {
    for name, disk in yandex_compute_disk.extra_disks : name => disk.id
  }
}