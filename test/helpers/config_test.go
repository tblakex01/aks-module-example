package helpers

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestShouldRunIntegrationTestsRequiresExplicitOptIn(t *testing.T) {
	t.Setenv("RUN_INTEGRATION_TESTS", "")
	assert.False(t, ShouldRunIntegrationTests())

	t.Setenv("RUN_INTEGRATION_TESTS", "true")
	assert.True(t, ShouldRunIntegrationTests())
}

func TestShouldRunExpressRouteTestsRequiresExplicitOptIn(t *testing.T) {
	t.Setenv("RUN_EXPRESSROUTE_TESTS", "")
	assert.False(t, ShouldRunExpressRouteTests())

	t.Setenv("RUN_EXPRESSROUTE_TESTS", "true")
	assert.True(t, ShouldRunExpressRouteTests())
}

func TestGetTestLocationUsesEnvOverride(t *testing.T) {
	t.Setenv("TEST_LOCATION", "West US 3")
	assert.Equal(t, "West US 3", GetTestLocation())
}

func TestGetTerraformOptionsAppliesDefaultsAndOverrides(t *testing.T) {
	t.Setenv("TERRAFORM_BINARY", "/tmp/terraform")

	options := GetTerraformOptions("/tmp/fixture", map[string]interface{}{
		"cluster_name": "aks-test",
	})

	assert.Equal(t, "/tmp/terraform", options.TerraformBinary)
	assert.Equal(t, "/tmp/fixture", options.TerraformDir)
	assert.Equal(t, "aks-test", options.Vars["cluster_name"])
	assert.Equal(t, "1.35", options.Vars["kubernetes_version"])
	assert.Equal(t, "East US", options.Vars["location"])
	assert.Equal(t, "terratest", options.Vars["tags"].(map[string]string)["Purpose"])
}

func TestGetRandomStringLength(t *testing.T) {
	assert.Len(t, GetRandomString(8), 8)
	assert.Empty(t, GetRandomString(0))
}

func TestGetUniqueResourceGroupNameUsesPrefix(t *testing.T) {
	name := GetUniqueResourceGroupName("rg-test")
	assert.Contains(t, name, "rg-test-")
	assert.Len(t, name, len("rg-test-")+6)
}
