# ============================================================================
# ФАЙЛ: terraform-module-lab/modules/network/main.tf
# РОЛЬ: создаёт VPC-сеть и подсеть.
# ВЫЗЫВАЕТСЯ из:
#   - terraform-module-lab/main.tf → module "network"
# ============================================================================

resource "yandex_vpc_network" "this" {
  name = var.network_name
}

resource "yandex_vpc_subnet" "this" {
  name           = var.subnet_name
  zone           = var.zone
  network_id     = yandex_vpc_network.this.id
  v4_cidr_blocks = [var.subnet_cidr]
}