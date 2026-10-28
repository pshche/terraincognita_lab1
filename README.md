### пояснение для проверяющего
До попадания БПЛА все прекрасно работало, к сожалению сейчас нельзя создавать новые диски, я писал тикет в поддержку и разбирал с ними вопрос, мне в конце ответили что это связанно с текущей ситуацией а так же пробовал разные варианты выбора обьемов и размеров дисков и тп.

С модулем разобрался и добавил фишки с динамичным возвратом айпи адресов и id дисков для комфортной генерации инфраструктуры, понимания процесса и оценки отлично.

До попадания 2 и 3го еще запускалось.

Делал локально, у нас не восстановили учебный gitlab, поэтому залил сюда

Основные секреты вынесены отдельно, в гите только публичные ключи, не акцентировал на фул безопасности.

На момент сдачи работы в облаке действуют временные ограничения (Resource allocation is restricted) на создание новых compute-дисков. Данный вопрос разбирался с поддержкой Yandex Cloud (тикет), ограничение связано с текущими событиями на стороне провайдера. Ранее инфраструктура успешно разворачивалась (terraform apply проходил).
Настоящий код модуля валиден (terraform validate проходит успешно). Секреты (приватные ключи, стейты) вынесены в .gitignore, в репозитории находятся только публичные SSH-ключи и код.
Прицепил скрин с ответом поодержки.


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