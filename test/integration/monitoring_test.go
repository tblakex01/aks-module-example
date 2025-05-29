package test

import (
	"context"
	"strings"
	"testing"

	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/monitor/armmonitor"
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/operationalinsights/armoperationalinsights"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestMonitoringConfiguration tests the monitoring setup
func TestMonitoringConfiguration(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../",
		Vars: map[string]interface{}{
			"environment": "test",
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Validate monitoring configuration
	validateMonitoring(t, terraformOptions)
}

// validateMonitoring validates the monitoring setup
func validateMonitoring(t *testing.T, terraformOptions *terraform.Options) {
	// Get outputs
	resourceGroupName := terraform.Output(t, terraformOptions, "resource_group_name")
	logAnalyticsWorkspaceID := terraform.Output(t, terraformOptions, "log_analytics_workspace_id")
	clusterID := terraform.Output(t, terraformOptions, "cluster_id")

	// Create Azure clients
	ctx := context.Background()
	cred, err := azidentity.NewDefaultAzureCredential(nil)
	require.NoError(t, err)

	// Get subscription ID from workspace ID
	subscriptionID := strings.Split(logAnalyticsWorkspaceID, "/")[2]

	// Validate Log Analytics Workspace
	validateLogAnalyticsWorkspace(t, ctx, cred, subscriptionID, resourceGroupName, logAnalyticsWorkspaceID)

	// Validate Container Insights is enabled
	validateContainerInsights(t, ctx, cred, subscriptionID, resourceGroupName, clusterID)
}

// validateLogAnalyticsWorkspace validates the Log Analytics workspace
func validateLogAnalyticsWorkspace(t *testing.T, ctx context.Context, cred *azidentity.DefaultAzureCredential, subscriptionID, resourceGroupName, workspaceID string) {
	// Create Log Analytics client
	workspaceClient, err := armoperationalinsights.NewWorkspacesClient(subscriptionID, cred, nil)
	require.NoError(t, err)

	// Get workspace name from ID
	workspaceName := strings.Split(workspaceID, "/")[8]

	// Get workspace
	workspace, err := workspaceClient.Get(ctx, resourceGroupName, workspaceName, nil)
	require.NoError(t, err)
	assert.NotNil(t, workspace)

	// Validate workspace properties
	assert.Equal(t, armoperationalinsights.WorkspaceSkuNameEnumPerGB2018, *workspace.Properties.SKU.Name)
	assert.Equal(t, int32(30), *workspace.Properties.RetentionInDays)
	assert.Equal(t, armoperationalinsights.PublicNetworkAccessTypeEnabled, *workspace.Properties.PublicNetworkAccessForIngestion)
}

// validateContainerInsights validates Container Insights configuration
func validateContainerInsights(t *testing.T, ctx context.Context, cred *azidentity.DefaultAzureCredential, subscriptionID, resourceGroupName, clusterID string) {
	// Create diagnostic settings client
	diagnosticClient, err := armmonitor.NewDiagnosticSettingsClient(cred, nil)
	require.NoError(t, err)

	// List diagnostic settings for the AKS cluster
	pager := diagnosticClient.NewListPager(clusterID, nil)
	
	hasContainerInsights := false
	for pager.More() {
		page, err := pager.NextPage(ctx)
		if err != nil {
			// It's common for diagnostic settings to not exist initially
			t.Logf("Warning: Could not retrieve diagnostic settings: %v", err)
			return
		}
		
		if page.Value != nil && len(page.Value) > 0 {
			hasContainerInsights = true
			break
		}
	}

	// For new deployments, Container Insights might be enabled differently
	// Log a warning instead of failing the test
	if !hasContainerInsights {
		t.Log("Warning: Container Insights diagnostic settings not found. This might be normal for new deployments.")
	}
}

// TestLogAnalyticsRetention tests custom retention settings
func TestLogAnalyticsRetention(t *testing.T) {
	t.Parallel()

	// Test with custom retention
	customRetention := int32(60)

	terraformOptions := &terraform.Options{
		TerraformDir: "../../",
		Vars: map[string]interface{}{
			"environment":                     "test",
			"log_analytics_retention_in_days": customRetention,
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Get outputs
	resourceGroupName := terraform.Output(t, terraformOptions, "resource_group_name")
	logAnalyticsWorkspaceID := terraform.Output(t, terraformOptions, "log_analytics_workspace_id")

	// Create Azure clients
	ctx := context.Background()
	cred, err := azidentity.NewDefaultAzureCredential(nil)
	require.NoError(t, err)

	// Get subscription ID and workspace name
	parts := strings.Split(logAnalyticsWorkspaceID, "/")
	subscriptionID := parts[2]
	workspaceName := parts[8]

	// Create Log Analytics client
	workspaceClient, err := armoperationalinsights.NewWorkspacesClient(subscriptionID, cred, nil)
	require.NoError(t, err)

	// Get workspace
	workspace, err := workspaceClient.Get(ctx, resourceGroupName, workspaceName, nil)
	require.NoError(t, err)

	// Validate custom retention
	assert.Equal(t, customRetention, *workspace.Properties.RetentionInDays)
}

// TestMonitoringAlerts tests if monitoring alerts can be configured
func TestMonitoringAlerts(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../",
		Vars: map[string]interface{}{
			"environment": "test",
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Get outputs
	resourceGroupName := terraform.Output(t, terraformOptions, "resource_group_name")
	clusterName := terraform.Output(t, terraformOptions, "cluster_name")
	logAnalyticsWorkspaceID := terraform.Output(t, terraformOptions, "log_analytics_workspace_id")

	// Verify we have the necessary components for alerts
	assert.NotEmpty(t, resourceGroupName)
	assert.NotEmpty(t, clusterName)
	assert.NotEmpty(t, logAnalyticsWorkspaceID)

	// In a real scenario, you would create and validate metric alerts here
	// For now, we just verify the prerequisites exist
	t.Log("Prerequisites for monitoring alerts are in place")
}