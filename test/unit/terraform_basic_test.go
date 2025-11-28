package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestTerraformBasicValidation validates the Terraform configuration
func TestTerraformBasicValidation(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../",
		NoColor:      true,
	}

	// Run terraform init and validate
	terraform.Init(t, terraformOptions)
	terraform.Validate(t, terraformOptions)
}

// TestTerraformPlanWithDefaults tests the Terraform plan with default values
func TestTerraformPlanWithDefaults(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../",
		PlanFilePath: "../../test-plan.out",
		NoColor:      true,
	}

	// Run terraform init and plan
	terraform.Init(t, terraformOptions)
	planExitCode := terraform.InitAndPlanWithExitCode(t, terraformOptions)

	// Verify the plan was successful
	assert.Equal(t, 0, planExitCode)
}

// TestTerraformPlanWithCustomValues tests the Terraform plan with custom values
func TestTerraformPlanWithCustomValues(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../",
		Vars: map[string]interface{}{
			"location":            "West US 2",
			"cluster_name":        "test-aks-cluster",
			"environment":         "test",
			"kubernetes_version":  "1.31.8",
			"system_node_count":   1,
			"spark_node_count":    2,
			"enable_expressroute": false,
		},
		PlanFilePath: "../../test-plan-custom.out",
		NoColor:      true,
	}

	// Run terraform init and plan
	terraform.Init(t, terraformOptions)
	planExitCode := terraform.InitAndPlanWithExitCode(t, terraformOptions)

	// Verify the plan was successful
	assert.Equal(t, 0, planExitCode)
}

// TestRequiredVariables tests that all required variables have defaults
func TestRequiredVariables(t *testing.T) {
	t.Parallel()

	// Test with minimal configuration (relying on defaults)
	terraformOptions := &terraform.Options{
		TerraformDir: "../../",
		NoColor:      true,
	}

	// This should succeed because all variables have defaults
	terraform.Init(t, terraformOptions)
	terraform.Validate(t, terraformOptions)
}
