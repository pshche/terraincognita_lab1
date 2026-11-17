### пояснение для проверяющего

Использован предыдущий проект, который приняли на максимальный бал
Добавлен TESTING.md с пояснениями
Добавлены каталоги
tests
test-results



# Terraform-модуль для развёртывания web/api в Yandex Cloud

Учебный проект: модуль создаёт две ВМ (`web` и `api`), подключает к `api` список дополнительных дисков через блок `dynamic`, а также возвращает ID дисков и внутренние IP-адреса ВМ.

## Структура

- `versions.tf` — версии Terraform и провайдера
- `variables.tf` — входные переменные корневого модуля
- `main.tf` — вызов дочерних модулей и настройка backend
- `outputs.tf` — выходные значения
- `modules/disks/` — дочерний модуль дисков (использует `for_each`)
- `modules/vms/` — дочерний модуль ВМ (`web`, `api`, `dynamic secondary_disk`, `data` для подсети)
- `terraform.tfvars.dev` — параметры для dev-окружения
- `terraform.tfvars.prod` — параметры для prod-окружения

## Требования

- Terraform >= 1.5.0
- Провайдер `yandex-cloud/yandex ~> 0.100`
- Настроенные переменные окружения для аутентификации:
  - `YC_CLOUD_ID`, `YC_FOLDER_ID`, `YC_SERVICE_ACCOUNT_KEY_FILE`
  - `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` (для S3-backend, если используется)

## Переменные

| Имя | Тип | Описание | Значение по умолчанию |
|---|---|---|---|
| `zone` | string | Зона доступности | `ru-central1-a` |
| `name_prefix` | string | Префикс для имён ресурсов | `msa` |
| `vm_names` | object | Имена ВМ web/api | `{ web = "web", api = "api" }` |
| `extra_disk_names` | list(string) | Имена доп. дисков | `["logs", "backup"]` |
| `extra_disk_type` | string | Тип дисков | `network-hdd` |
| `extra_disk_size` | number | Размер дисков (ГБ) | `20` |
| `vm_specification` | map(object) | Параметры ВМ | см. variables.tf |
| `ssh_public_key` | string | Публичный SSH-ключ | — |

## Валидации

- `extra_disk_type` ∈ {`network-hdd`, `network-ssd`}
- `extra_disk_size` > 1
- `vm_specification.cores` = 2
- `vm_specification.memory` ∈ {2, 4}
- `vm_specification.disk_size` > 1
- `core_fraction` — опциональный параметр (по умолчанию `20`)

## Запуск для dev

terraform init
terraform workspace new dev
terraform workspace select dev
terraform plan  -var-file="terraform.tfvars.dev"
terraform apply -var-file="terraform.tfvars.dev"

## Запуск для prod
terraform init
terraform workspace new prod
terraform workspace select prod
terraform plan  -var-file="terraform.tfvars.prod"
terraform apply -var-file="terraform.tfvars.prod"


## Уничтожение инфраструктуры
terraform workspace select dev
terraform destroy -var-file="terraform.tfvars.dev"

terraform workspace select prod
terraform destroy -var-file="terraform.tfvars.prod"