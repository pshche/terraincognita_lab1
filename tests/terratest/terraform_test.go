package terratest

import (
	"encoding/json"
	"path/filepath"
	"strings"
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
    // Хранилище для привязок secondary_disk: ключ — имя ВМ, значение — слайс имен дисков
    vmToDisks := map[string][]string{}
    // Флаг для строгой проверки nat у ВМ api
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
                // Проверяем именно на true, отсутствие поля или любое другое значение (nil, false) провалит тест
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
                // Terraform может отдавать secondary_disk как map (один диск) или []interface{} (несколько)
                switch v := secRaw.(type) {
                case []interface{}:
                    for _, item := range v {
                        if diskMap, ok := item.(map[string]interface{}); ok {
                            if diskName, ok := diskMap["disk_name"].(string); ok {
                                vmToDisks[rc.Name] = append(vmToDisks[rc.Name], diskName)
                            }
                        }
                    }
                case map[string]interface{}:
                    if diskName, ok := v["disk_name"].(string); ok {
                        vmToDisks[rc.Name] = append(vmToDisks[rc.Name], diskName)
                    }
                }
            }
		case "yandex_compute_disk":
			after, _ := rc.Change.After.(map[string]interface{})
			if name, ok := after["name"].(string); ok {
				disks[name] = true
			} else {
				disks[rc.Name] = true
			}
		}
	}
	assert.True(t, vms["web"], "в плане должна быть ВМ web")
	assert.True(t, vms["api"], "в плане должна быть ВМ api")
    // Дополнительная строгая проверка, если цикл по ресурсам по какой-то причине не зашел в ветку api
    assert.True(t, apiHasNat, "флаг nat для ВМ api не был проверен в основном цикле")

	var hasLogs, hasBackup bool
	for n := range disks {
		if strings.Contains(n, "logs") {
			hasLogs = true
		}
		if strings.Contains(n, "backup") {
			hasBackup = true
		}
	}
	assert.True(t, hasLogs, "в плане должен быть дополнительный диск с 'logs' в имени")
	assert.True(t, hasBackup, "в плане должен быть дополнительный диск с 'backup' в имени")

    // Проверка, что именно api подключает оба диска через secondary_disk
    apiDisks, apiHasDisks := vmToDisks["api"]
    assert.True(t, apiHasDisks, "у ВМ api в конфигурации должен быть блок secondary_disk")
    assert.Len(t, apiDisks, 2, "ВМ api должна подключать ровно два дополнительных диска")
    assert.Contains(t, apiDisks, "logs", "ВМ api должна подключать диск logs через secondary_disk")
    assert.Contains(t, apiDisks, "backup", "ВМ api должна подключать диск backup через secondary_disk")
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
		if size, ok := after["size"].(float64); ok && int(size) == wantSize {
			found = true
			break
		}
	}
	assert.Truef(t, found, "не найден диск с ожидаемым размером %d ГБ", wantSize)
}