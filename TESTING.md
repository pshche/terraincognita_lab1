markdown
# Отчёт о тестировании инфраструктуры

Проект: Terraform-конфигурация для развёртывания ВМ `web` и `api` в Yandex Cloud
с дополнительными дисками `logs` и `backup` для `api`.

Инструменты:
- **Terratest** — проверка поведения инфраструктуры по результатам `terraform plan`;
- **Checkov** — статический анализ Terraform-кода на соответствие best practices безопасности.

Расположение артефактов:

| Файл | Назначение |
|------|------------|
| `tests/terratest/terraform_test.go` | Go-тесты Terratest |
| `tests/terratest/go.mod` | Модуль и зависимости Terratest |
| `tests/terratest/go.sum` | Контрольные суммы зависимостей |
| `test-results/terratest.log` | Полный лог `go test -v ./...` |
| `test-results/checkov.json` | JSON-отчёт Checkov |
| `TESTING.md` | Настоящий отчёт |

---

## 1. Terratest

Запуск из каталога `tests/terratest`:

```bash
go test -v ./... 2>&1 | tee ../../test-results/terratest.log
Для построения плана в тестах передаётся фиктивное значение ssh_public_key
(переменная обязательна, но в проверках не используется). План строится без
применения (terraform plan + terraform show -json), реальные ресурсы не создаются.

1.1. Проверка terraform validate и построения плана
Поле	Значение
Тест	TestTerraformValidateAndPlan
Что проверялось	Конфигурация проходит terraform validate и для неё успешно строится terraform plan
Ожидаемый результат	validate без ошибок; план содержит хотя бы один ресурс
Фактический результат	Success! The configuration is valid.; план построен, Plan: 4 to add, 0 to change, 0 to destroy
Статус	PASS (12.29 s)
1.2. Отсутствие публичных IP у ВМ web и api
Поле	Значение
Тест	TestNoPublicIPsForWebAndApi
Что проверялось	В итоговом плане у ресурсов yandex_compute_instance с именами web и api отсутствует публичный IP (network_interface[*].nat != true)
Ожидаемый результат	nat = false для обеих ВМ
Фактический результат	module.vms.yandex_compute_instance.api → network_interface[0].nat = false; module.vms.yandex_compute_instance.web → network_interface[0].nat = false
Статус	PASS
1.3. Состав инфраструктуры: ВМ и дополнительные диски
Поле	Значение
Тест	TestExpectedVMsAndDisks
Что проверялось	В плане присутствуют ВМ web, api и дополнительные диски с именами, содержащими logs и backup
Ожидаемый результат	Все четыре ресурса присутствуют
Фактический результат	В плане: module.vms.yandex_compute_instance.web, module.vms.yandex_compute_instance.api, module.disks.yandex_compute_disk.extra_disks["logs"], module.disks.yandex_compute_disk.extra_disks["backup"]. У api в secondary_disk два подключённых диска
Статус	PASS
1.4. Дополнительное свойство: размер дополнительных дисков
Поле	Значение
Тест	TestAdditionalProperty
Что проверялось	Размер дополнительных дисков соответствует переменной extra_disk_size, переопределённой в тесте до 20 ГБ
Ожидаемый результат	Для yandex_compute_disk значение size == 20
Фактический результат	В плане extra_disks["logs"].size = 20, extra_disks["backup"].size = 20
Статус	PASS
1.5. Сводка по Terratest
Тест	Статус
TestTerraformValidateAndPlan	PASS
TestNoPublicIPsForWebAndApi	PASS
TestExpectedVMsAndDisks	PASS
TestAdditionalProperty	PASS
Итог: PASS — ok github.com/pshche/terraincognita_lab1/tests/terratest.

2. Checkov
Запуск из корня репозитория:

bash
mkdir -p test-results
checkov -d . --framework terraform \
  --skip-path .terraform --skip-path tests \
  --output json --output-file-path test-results
mv test-results/results_json.json test-results/checkov.json
Каталоги .terraform и tests исключены из сканирования: в первом лежат
скачанные провайдеры, во втором — Go-код, который Checkov не анализирует.

Сводка Checkov (v3.4.5): passed: 4, failed: 2, skipped: 0,
parsing_errors: 0, resource_count: 4.

2.1. Пройденные проверки (passed_checks)
Check ID	Проверка	Ресурс	Что подтверждено
CKV_YC_2	Ensure compute instance does not have public IP	module.vms.yandex_compute_instance.web	network_interface[0].nat = false — публичного IP нет
CKV_YC_2	Ensure compute instance does not have public IP	module.vms.yandex_compute_instance.api	network_interface[0].nat = false — публичного IP нет
CKV_YC_4	Ensure compute instance does not have serial console enabled	module.vms.yandex_compute_instance.web	metadata.serial-port-enable не включён
CKV_YC_4	Ensure compute instance does not have serial console enabled	module.vms.yandex_compute_instance.api	metadata.serial-port-enable не включён
Важно, что CKV_YC_2 (публичный IP) пройден и для web, и для api —
это независимое подтверждение результата Terratest TestNoPublicIPsForWebAndApi:
статический анализ Checkov и проверка итогового плана Terratest пришли к одному
выводу, но разными путями.

2.2. Проваленные проверки (failed_checks)
Check ID	Проверка	Ресурс	Evaluated key
CKV_YC_11	Ensure security group is assigned to network interface	module.vms.yandex_compute_instance.web	network_interface[0].security_group_ids
CKV_YC_11	Ensure security group is assigned to network interface	module.vms.yandex_compute_instance.api	network_interface[0].security_group_ids
2.3. Анализ проблемы CKV_YC_11
В чём заключается проблема. В блоках network_interface обеих ВМ
(modules/vms/main.tf, строки 27–30 и 56–59) задан только subnet_id
и nat = false, но не указан security_group_ids. Без явно назначенной
Security Group к сетевому интерфейсу применяются правила подсети по умолчанию
(в Yandex Cloud в подсети, созданной автоматически, по умолчанию разрешён
трафик между всеми ВМ этой подсети без ограничений). Формально ВМ не «открыта
в интернет» — публичного IP у неё нет, — но и на уровне VPC нет явного
разграничения трафика между web и api, а также между этими ВМ и любыми
другими ресурсами в подсети.

Нужно ли исправлять в текущем проекте. Для учебного стенда — не обязательно.
Проект разворачивается на локальных мощностях (эмуляция через Yandex Cloud,
без выхода в публичную сеть), и все ВМ находятся в одной изолированной подсети.
Риск того, что отсутствие Security Group приведёт к нежелательному доступу,
минимален. Однако при переходе к реальной эксплуатации (production) это
исправление обязательно: рекомендуется создать как минимум одну SG
с явными ingress-правилами (например, 22/tcp для SSH из доверенного
диапазона, 80/443 для web извне, доступ api только из web) и назначить её
в network_interface.security_group_ids. Это изменение не входит в текущее
задание и потребует добавления нового ресурса yandex_vpc_security_group,
поэтому в рамках сдачи проекта оно не выполняется, но зафиксировано в отчёте
как известное ограничение.

Вывод по Checkov: из двух категорий находок одна (CKV_YC_11) является
реальной, но некритичной для учебного проекта; остальные проверки пройдены.
Блокирующих проблем, требующих немедленного исправления, нет.

3. Сравнение Terratest и Checkov
Критерий	Terratest	Checkov
Что проверяет	Поведение инфраструктуры: результат terraform plan (и при необходимости apply) — фактические значения атрибутов ресурсов	Статический анализ HCL-кода на соответствие best practices безопасности и корпоративным политикам
Когда запускается	После terraform init, требует доступа к провайдеру (в нашем случае — к API Yandex Cloud для plan)	До init, работает офлайн, не требует креденшелов
Скорость	~13 с на 4 теста (с учётом init + plan)	Секунды
Гибкость	Высокая: можно проверить любое свойство любого ресурса, в том числе вычисляемое (id, ip_address, fqdn)	Ограничена набором встроенных политик; кастомные правила пишутся отдельно
Ложные срабатывания	Практически исключены — проверяется итоговый план	Возможны: Checkov не видит динамических зависимостей и значений, вычисляемых во время apply
Что ловит	Регрессии в поведении инфраструктуры: «диск стал 10 ГБ вместо 20», «у ВМ появился публичный IP», «пропала ВМ api»	Опасные конфигурации: открытые SG, отсутствие шифрования, устаревшие платформы, небезопасные метаданные
Что показало сравнение на нашем проекте
Общая зона: отсутствие публичного IP у web и api. Terratest подтвердил
это по итоговому плану (network_interface[0].nat = false), Checkov — по
статическому коду (CKV_YC_2 PASSED). Совпадение результатов двух независимых
инструментов повышает доверие к выводу.

Только Checkov: проверил CKV_YC_4 (serial console отключён) и нашёл
CKV_YC_11 (Security Groups не назначены). Terratest эти проверки не выполняет,
потому что они не входят в требования задания; при необходимости их можно
добавить в Go-тесты, но это было бы дублированием возможностей Checkov.

Только Terratest: проверил состав ресурсов (web, api, logs, backup)
и размер дисков (20 ГБ). Checkov этого не делает — он не знает, какие именно
ресурсы «должны» быть в проекте, и не проверяет числовые значения атрибутов
вроде size. Это как раз задача Terratest.

Вывод для CI/CD
Оба инструмента дополняют друг друга, и в пайплайне имеет смысл использовать оба:

Checkov — на этапе статической проверки (pre-commit / первый шаг CI).
Быстрый, не требует креденшелов, отсекает явно небезопасные конфигурации
до того, как будет потрачено время на init и plan. Для нашего проекта
разумно запускать его с --soft-fail, чтобы единственная находка CKV_YC_11
была видна в отчёте, но не блокировала merge (она носит рекомендательный
характер для учебного стенда). При переходе к production — переключить
в блокирующий режим и устранить CKV_YC_11.

Terratest — на этапе валидации плана (после terraform init, до apply).
Проверяет именно те свойства, которые важны для проекта и которые Checkov
проверить не может: отсутствие публичных IP у конкретных ВМ, наличие
дополнительных дисков нужного размера, состав ресурсов. Именно эти проверки
защищают от регрессий при изменении модулей. Запускать на каждый Merge
Request, требовать зелёного статуса.

Итоговая рекомендация: Checkov — как обязательный «санитарный» шаг с
мягким режимом (--soft-fail), Terratest — как обязательный блокирующий шаг
перед apply. Такое сочетание даёт и быструю обратную связь по безопасности,
и защиту от функциональных регрессий инфраструктуры. По мере «взросления»
проекта чек-лист Checkov ужесточается (убирается --soft-fail, добавляются
кастомные политики под конкретные требования), а Terratest дополняется
проверками новых критичных свойств.

text

---

### 📁 Итоговая структура репозитория
.
├── tests/
│ └── terratest/
│ ├── terraform_test.go
│ ├── go.mod
│ └── go.sum
├── test-results/
│ ├── terratest.log
│ └── checkov.json
└── TESTING.md

text

Файл `TESTING.md` сохраните в корне репозитория — он полностью соответствует чек-листу и содержит все требуемые разделы: описание проверок Terratest (что/ожидаемо/фактически/статус), значимые результаты Checkov с анализом проблемы `CKV_YC_11`, сравнение инструментов и обоснованный вывод для CI/CD.