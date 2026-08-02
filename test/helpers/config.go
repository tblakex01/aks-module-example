package helpers

import (
	"crypto/rand"
	"encoding/hex"
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func GetTerraformOptions(terraformDir string, vars map[string]interface{}) *terraform.Options {
	defaultVars := map[string]interface{}{
		"location":           GetTestLocation(),
		"kubernetes_version": "1.35",
		"tags": map[string]string{
			"Environment": "test",
			"Purpose":     "terratest",
			"Temporary":   "true",
		},
	}

	for k, v := range vars {
		defaultVars[k] = v
	}

	return &terraform.Options{
		TerraformBinary: os.Getenv("TERRAFORM_BINARY"),
		TerraformDir:    terraformDir,
		Vars:            defaultVars,
		NoColor:         true,
		MaxRetries:      3,
		RetryableTerraformErrors: map[string]string{
			".*timeout.*":                   "Timeout error occurred",
			".*Client.Timeout.*":            "Client timeout error",
			".*could not be reached.*":      "Service temporarily unavailable",
			".*connection reset by peer.*":  "Connection was reset",
			".*TooManyRequests.*":           "Rate limit exceeded",
			".*ServiceUnavailable.*":        "Service temporarily unavailable",
			".*InternalServerError.*":       "Internal server error",
			".*ResourceGroupNotFound.*":     "Resource group not found (eventual consistency)",
			".*AuthorizationFailed.*":       "Authorization failed (eventual consistency)",
			".*RequestDisallowedByPolicy.*": "Policy evaluation in progress",
		},
	}
}

func GetTestLocation() string {
	if location := os.Getenv("TEST_LOCATION"); location != "" {
		return location
	}
	return "East US"
}

func ShouldRunIntegrationTests() bool {
	return os.Getenv("RUN_INTEGRATION_TESTS") == "true"
}

func RequireIntegration(t *testing.T) {
	t.Helper()

	if !ShouldRunIntegrationTests() {
		t.Skip("set RUN_INTEGRATION_TESTS=true to run Azure integration tests")
	}
}

func ShouldRunExpressRouteTests() bool {
	return os.Getenv("RUN_EXPRESSROUTE_TESTS") == "true"
}

func GetUniqueResourceGroupName(prefix string) string {
	return prefix + "-" + GetRandomString(6)
}

func GetRandomString(length int) string {
	if length <= 0 {
		return ""
	}

	bytes := make([]byte, length)
	if _, err := rand.Read(bytes); err != nil {
		panic(err)
	}

	return hex.EncodeToString(bytes)[:length]
}
