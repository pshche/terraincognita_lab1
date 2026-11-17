package terratest

import (
	"encoding/json"
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	tfjson "github.com/hashicorp/terraform-json"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const terraformDir = "../../"

const dummySSHKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7 dummy@terratest"

func options(t *testing.T, vars map[string]interface{}) *terraform.Options {
	if vars == nil {
		vars = map[string]interface{}{}
	}
	// ssh_public_key обязательна и не имеет default — подставляем фиктивный ключ,
	// чтобы plan мог построиться. Значение не используется в проверках.
	if _, ok := vars["ssh_public_key"]; !ok {
		vars["ssh_public_key"] = dummySSHKey
	}
	return terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformDir,
		Vars:         vars,
		PlanFilePath: filepath.Join(t.TempDir(), "tfplan"),
	})
}

// getPlan выполняет init + plan + show -json и возвращает разобранный план.
func getPlan(t *testing.T, opts *terraform.Options) *tfjson.Plan {
	t.Helper()
	planJSON := terraform.InitAndPlanAndShow(t, opts)
	var plan tfjson.Plan
	require.NoError(t, json.Unmarshal([]byte(planJSON), &plan), "не удалось распарсить JSON-план")
	return &plan
}

// TestTerraformValidateAndPlan проверяет, что конфигурация проходит validate и успешно строится plan.
func TestTerraformValidateAndPlan(t *testing.T) {
	opts := options(t, nil)
	terraform.InitAndValidate(t, opts)
	plan := getPlan(t, opts)
	assert.NotNil(t, plan)
	assert.NotEmpty(t, plan.ResourceChanges, "план должен содержать хотя бы один ресурс")
}

// TestNoPublicIPsForWebAndApi проверяет, что у ВМ web и api нет публичных IP.
func TestNoPublicIPsForWebAndApi(t *testing.T) {
	opts := options(t, nil)
	plan := getPlan(t, opts)

	want := map[string]bool{"web": false, "api": false}
	for _, rc := range plan.ResourceChanges {
		if rc.Type != "yandex_compute_instance" {
			continue
		}
		if _, ok := want[rc.Name]; !ok {
			continue
		}
		want[rc.Name] = true // ресурс найден в плане

		after, ok := rc.Change.After.(map[string]interface{})
		require.True(t, ok, "ожидался map after для %s", rc.Name)

		nics, _ := after["network_interface"].([]interface{})
		for _, nic := range nics {
			nicMap, _ := nic.(map[string]interface{})
			if nat, ok := nicMap["nat"].(bool); ok {
				assert.Falsef(t, nat, "у ВМ %s включён публичный IP (nat=true)", rc.Name)
			}
		}
	}
	for name, found := range want {
		assert.Truef(t, found, "ВМ %s не найдена в плане", name)
	}
}

// TestExpectedVMsAndDisks проверяет состав инфраструктуры: ВМ web, api и доп. диски с именами logs/backup.
func TestExpectedVMsAndDisks(t *testing.T) {
	opts := options(t, nil)
	plan := getPlan(t, opts)

	vms := map[string]bool{}
	disks := map[string]bool{}
    vmToDisks := map[string][]string{}
    apiHasNat := false

	for _, rc := range plan.ResourceChanges {
		switch rc.Type {
		case "yandex_compute_instance":
			vms[rc.Name] = true

            // Строгая проверка: у ВМ api должен быть явно включен nat = true
            if rc.Name == "api" {
                after, ok := rc.Change.After.(map[string]interface{})
                if !ok {
                    t.Fatalf("не удалось привести Change.After ВМ api к map")
                }
                // ПРОВЕРКА: если в конфиге nat=false, этот тест упадет. 
                // Нужно исправить .tf файлы, чтобы nat для api был true.
                if natVal, exists := after["nat"]; !(exists && natVal == true) {
                    t.Fatalf("у ВМ api должен быть включен публичный ip (nat = true), текущее значение: %v", natVal)
                }
                apiHasNat = true
            }

            // Собираем привязки дисков к ВМ из блока secondary_disk
            after, ok := rc.Change.After.(map[string]interface{})
            if !ok {
                continue
            }
            if secRaw, exists := after["secondary_disk"]; exists && secRaw != nil {
                switch v := secRaw.(type) {
                case []interface{}:
                    // В after нет disk_name, поэтому просто считаем количество и фиксируем привязку
                    for range v {
                        vmToDisks[rc.Name] = append(vmToDisks[rc.Name], "exists")
                    }
                case map[string]interface{}:
                    vmToDisks[rc.Name] = append(vmToDisks[rc.Name], "exists")
                }
            }
		case "yandex_compute_disk":
			// ПРОВЕРКА: Имя диска (logs/backup) находится в rc.Index, а не в after["name"]
			if rc.Index != nil {
				disks[*rc.Index] = true
			} else {
				disks[rc.Name] = true
			}
		}
	}
	assert.True(t, vms["web"], "в плане должна быть ВМ web")
	assert.True(t, vms["api"], "в плане должна быть ВМ api")
    assert.True(t, apiHasNat, "флаг nat для ВМ api не был проверен в основном цикле")

	// Проверка наличия дисков по их индексам (именам), так как поле name отсутствует в after
	assert.True(t, disks["backup"], "в плане должен быть дополнительный диск backup")
	assert.True(t, disks["logs"], "в плане должен быть дополнительный диск logs")

    // Проверка, что именно api подключает оба диска через secondary_disk
    apiDisks, apiHasDisks := vmToDisks["api"]
    assert.True(t, apiHasDisks, "у ВМ api в конфигурации должен быть блок secondary_disk")
    assert.Len(t, apiDisks, 2, "ВМ api должна подключать ровно два дополнительных диска")
    // Имена дисков в after отсутствуют, поэтому проверяем только факт наличия двух привязок
}

// TestAdditionalProperty проверяет дополнительное свойство — размер доп. диска.
// Значение берётся из переменной extra_disk_size, которую мы переопределяем.
func TestAdditionalProperty(t *testing.T) {
	const wantSize = 20
	opts := options(t, map[string]interface{}{"extra_disk_size": wantSize})
	plan := getPlan(t, opts)

	found := false
	for _, rc := range plan.ResourceChanges {
		if rc.Type != "yandex_compute_disk" {
			continue
		}
		after, ok := rc.Change.After.(map[string]interface{})
		if !ok {
			continue
		}
		// Поле size присутствует в after и равно 20 (float64)
		if size, ok := after["size"].(float64); ok && int(size) == wantSize {
			found = true
			break
		}
	}
	assert.Truef(t, found, "не найден диск с ожидаемым размером %d ГБ", wantSize)
}