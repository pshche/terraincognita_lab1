# ============================================================================
# ФАЙЛ: terraform-module-lab/modules/disks/main.tf
# РОЛЬ: создаёт дополнительные диски через for_each.
# ВЫЗЫВАЕТСЯ из:
#   - terraform-module-lab/main.tf → module "disks"
# ПРИНИМАЕТ переменные из:
#   - terraform-module-lab/modules/disks/variables.tf
# ОТДАЁТ результат в:
#   - terraform-module-lab/modules/disks/outputs.tf → disk_ids
# ============================================================================

resource "yandex_compute_disk" "extra_disks" {
  # for_each по set из списка имён. Создаёт по одному диску на каждое имя.
  # toset() нужен, потому что for_each принимает set или map, но не list.
  # var.disk_names ← modules/disks/variables.tf ← main.tf (module "disks")
  for_each = toset(var.disk_names)

  # each.key — текущее имя диска ("logs", "backup").
  # Диск получает имя, равное своему ключу.
  name = each.key

  # Тип диска: network-hdd или network-ssd.
  # var.disk_type ← modules/disks/variables.tf ← main.tf (module "disks")
  type = var.disk_type

  # Зона, в которой создаётся диск. Должна совпадать с зоной ВМ.
  # var.zone ← modules/disks/variables.tf ← main.tf (module "disks")
  zone = var.zone

  # Размер диска в ГБ.
  # var.disk_size ← modules/disks/variables.tf ← main.tf (module "disks")
  size = var.disk_size
}