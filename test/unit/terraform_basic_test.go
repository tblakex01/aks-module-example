package test

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/require"
)

func repoCopy(t *testing.T) string {
	t.Helper()

	return test_structure.CopyTerraformFolderToTemp(t, "../../", ".")
}

func newTerraformOptions(terraformDir string) *terraform.Options {
	return &terraform.Options{
		TerraformBinary: os.Getenv("TERRAFORM_BINARY"),
		TerraformDir:    terraformDir,
		NoColor:         true,
	}
}

func TestModuleTerraformTests(t *testing.T) {
	t.Helper()

	ctx := context.Background()
	copyDir := repoCopy(t)
	options := newTerraformOptions(filepath.Join(copyDir, "modules", "aks"))

	terraform.InitContext(t, ctx, options)
	output, err := terraform.RunTerraformCommandContextE(t, ctx, options, "test", "-no-color")
	require.NoError(t, err, output)
}

func TestModuleFixtureValidate(t *testing.T) {
	t.Parallel()

	copyDir := repoCopy(t)
	terraformOptions := newTerraformOptions(filepath.Join(copyDir, "test", "fixtures", "module"))

	ctx := context.Background()
	terraform.InitContext(t, ctx, terraformOptions)
	terraform.ValidateContext(t, ctx, terraformOptions)
}
