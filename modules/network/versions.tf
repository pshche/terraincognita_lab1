# ============================================================================
# ФАЙЛ: terraform-module-lab/modules/network/versions.tf
# РОЛЬ: объявление провайдера для дочернего модуля.
# ============================================================================
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}