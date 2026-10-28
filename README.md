### пояснение для проверяющего
До попадания БПЛА все прекрасно работало, к сожалению сейчас нельзя создавать новые диски, я писал тикет в поддержку и разбирал с ними вопрос, мне в конце ответили
что это связанно с текущей ситуацией (хотя до этого получил дополнительный опыт, так как несколько раз менял на другие "default-ru-central1-a" в связи с событиями)
а так же пробовал разные варианты выбора обьемов и размеров дисков и тп, прицепил скрин для инфо.

С модулем разобрался и добавил фишки с динамичным возвратом айпи адресов и id дисков для комфортной генерации инфраструктуры, понимания процесса и оценки отлично.



До попадания 2 и 3го еще запускалось.

Делал локально, у нас не восстановили учебный gitlab, поэтому залил сюда

Основные секреты вынесены отдельно, в гите только публичные ключи, не акцентировал на фул безопасности.


# Terraform-модуль для развёртывания web/api в Yandex Cloud

## Структура

- `versions.tf` — версии Terraform и провайдера
- `variables.tf` — входные переменные
- `main.tf` — вызов дочерних модулей
- `outputs.tf` — выходные значения
- `modules/disks/` — модуль дисков
- `modules/vms/` — модуль ВМ
- `terraform.tfvars.dev` — параметры для dev
- `terraform.tfvars.prod` — параметры для prod

## Запуск для dev

```bash
terraform init
terraform workspace new dev
terraform workspace select dev
terraform plan  -var-file="terraform.tfvars.dev"
terraform apply -var-file="terraform.tfvars.dev"
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
| `subnet_name` | string | Имя существующей подсети | `default-ru-central1-a` |
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

## Запуск для dev

```bash
terraform init
terraform plan  -var-file="terraform.tfvars.dev"
terraform apply -var-file="terraform.tfvars.dev"