package helpers

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

// GetTerraformOptions returns terraform options with common settings
func GetTerraformOptions(t *testing.T, terraformDir string, vars map[string]interface{}) *terraform.Options {
	// Set default variables if not provided
	defaultVars := map[string]interface{}{
		"environment":         "test",
		"location":           GetTestLocation(),
		"system_node_count":  1,
		"spark_node_count":   1,
		"kubernetes_version": "1.31.8",
	}

	// Merge provided vars with defaults
	for k, v := range vars {
		defaultVars[k] = v
	}

	return &terraform.Options{
		TerraformDir: terraformDir,
		Vars:         defaultVars,
		NoColor:      true,
		MaxRetries:   3,
		RetryableTerraformErrors: map[string]string{
			".*timeout.*":                    "Timeout error occurred",
			".*Client.Timeout.*":             "Client timeout error",
			".*could not be reached.*":       "Service temporarily unavailable",
			".*connection reset by peer.*":   "Connection was reset",
			".*TooManyRequests.*":            "Rate limit exceeded",
			".*ServiceUnavailable.*":         "Service temporarily unavailable",
			".*InternalServerError.*":        "Internal server error",
			".*ResourceGroupNotFound.*":      "Resource group not found (eventual consistency)",
			".*AuthorizationFailed.*":        "Authorization failed (eventual consistency)",
			".*RequestDisallowedByPolicy.*":  "Policy evaluation in progress",
		},
	}
}

// GetTestLocation returns the Azure location for testing
func GetTestLocation() string {
	// Check for environment variable first
	if location := os.Getenv("TEST_LOCATION"); location != "" {
		return location
	}
	// Default to East US for testing
	return "East US"
}

// GetTestSubscriptionID returns the Azure subscription ID for testing
func GetTestSubscriptionID() string {
	// Try to get from environment variable
	if subID := os.Getenv("ARM_SUBSCRIPTION_ID"); subID != "" {
		return subID
	}
	// Try Azure CLI default subscription
	if subID := os.Getenv("AZURE_SUBSCRIPTION_ID"); subID != "" {
		return subID
	}
	return ""
}

// ShouldRunIntegrationTests checks if integration tests should run
func ShouldRunIntegrationTests() bool {
	// Check for environment variable
	if os.Getenv("RUN_INTEGRATION_TESTS") == "true" {
		return true
	}
	// Check for CI environment
	if os.Getenv("CI") == "true" {
		return true
	}
	return false
}

// ShouldRunExpressRouteTests checks if ExpressRoute tests should run
func ShouldRunExpressRouteTests() bool {
	// ExpressRoute tests require existing hub infrastructure
	return os.Getenv("RUN_EXPRESSROUTE_TESTS") == "true"
}

// GetUniqueResourceGroupName generates a unique resource group name for testing
func GetUniqueResourceGroupName(prefix string) string {
	return prefix + "-" + GetRandomString(6)
}

// GetRandomString generates a random string of specified length
func GetRandomString(length int) string {
	const charset = "abcdefghijklmnopqrstuvwxyz0123456789"
	b := make([]byte, length)
	for i := range b {
		b[i] = charset[randInt(len(charset))]
	}
	return string(b)
}

// randInt generates a random integer
func randInt(max int) int {
	// Simple implementation - in production use crypto/rand
	return int(os.Getpid()+int(os.Getppid())) % max
}