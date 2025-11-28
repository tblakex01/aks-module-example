package test

import (
	"context"
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/containerservice/armcontainerservice/v4"
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/resources/armresources"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestAKSClusterDeployment tests the full deployment of the AKS cluster
func TestAKSClusterDeployment(t *testing.T) {
	t.Parallel()

	// Create a unique test environment
	uniqueID := strings.ToLower(random.UniqueId())
	testName := fmt.Sprintf("test-aks-%s", uniqueID)

	// Copy the terraform folder to a temp folder
	tempTestFolder := test_structure.CopyTerraformFolderToTemp(t, "../../", ".")

	terraformOptions := &terraform.Options{
		TerraformDir: tempTestFolder,
		Vars: map[string]interface{}{
			"location":            "East US",
			"cluster_name":        testName,
			"environment":         "test",
			"kubernetes_version":  "1.31.8",
			"system_node_count":   1,
			"spark_node_count":    1,
			"enable_expressroute": false,
		},
		NoColor: true,
	}

	// Clean up resources at the end
	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraform.Destroy(t, terraformOptions)
	})

	// Deploy the infrastructure
	test_structure.RunTestStage(t, "deploy", func() {
		terraform.InitAndApply(t, terraformOptions)
	})

	// Validate the infrastructure
	test_structure.RunTestStage(t, "validate", func() {
		validateAKSCluster(t, terraformOptions)
	})
}

// validateAKSCluster validates the deployed AKS cluster
func validateAKSCluster(t *testing.T, terraformOptions *terraform.Options) {
	// Get outputs
	resourceGroupName := terraform.Output(t, terraformOptions, "resource_group_name")
	clusterName := terraform.Output(t, terraformOptions, "cluster_name")
	clusterID := terraform.Output(t, terraformOptions, "cluster_id")

	// Verify outputs are not empty
	assert.NotEmpty(t, resourceGroupName)
	assert.NotEmpty(t, clusterName)
	assert.NotEmpty(t, clusterID)

	// Create Azure clients
	ctx := context.Background()
	cred, err := azidentity.NewDefaultAzureCredential(nil)
	require.NoError(t, err)

	// Get subscription ID from cluster ID
	subscriptionID := strings.Split(clusterID, "/")[2]

	// Verify resource group exists
	validateResourceGroup(t, ctx, cred, subscriptionID, resourceGroupName)

	// Verify AKS cluster properties
	validateAKSClusterProperties(t, ctx, cred, subscriptionID, resourceGroupName, clusterName)
}

// validateResourceGroup validates the resource group exists
func validateResourceGroup(t *testing.T, ctx context.Context, cred *azidentity.DefaultAzureCredential, subscriptionID, resourceGroupName string) {
	resourceGroupClient, err := armresources.NewResourceGroupsClient(subscriptionID, cred, nil)
	require.NoError(t, err)

	rg, err := resourceGroupClient.Get(ctx, resourceGroupName, nil)
	require.NoError(t, err)
	assert.NotNil(t, rg)
	assert.Equal(t, resourceGroupName, *rg.Name)
}

// validateAKSClusterProperties validates the AKS cluster properties
func validateAKSClusterProperties(t *testing.T, ctx context.Context, cred *azidentity.DefaultAzureCredential, subscriptionID, resourceGroupName, clusterName string) {
	aksClient, err := armcontainerservice.NewManagedClustersClient(subscriptionID, cred, nil)
	require.NoError(t, err)

	// Get the cluster with timeout
	ctx, cancel := context.WithTimeout(ctx, 5*time.Minute)
	defer cancel()

	cluster, err := aksClient.Get(ctx, resourceGroupName, clusterName, nil)
	require.NoError(t, err)
	require.NotNil(t, cluster)

	// Validate cluster properties
	assert.Equal(t, clusterName, *cluster.Name)
	assert.Equal(t, "Succeeded", string(*cluster.Properties.ProvisioningState))

	// Validate it's a private cluster
	assert.True(t, *cluster.Properties.APIServerAccessProfile.EnablePrivateCluster)

	// Validate SKU
	assert.Equal(t, "Standard", string(*cluster.SKU.Tier))

	// Validate identity type
	assert.Equal(t, armcontainerservice.ResourceIdentityTypeSystemAssigned, *cluster.Identity.Type)

	// Validate Azure RBAC is enabled
	assert.True(t, *cluster.Properties.AADProfile.EnableAzureRBAC)

	// Validate workload identity is enabled
	assert.NotNil(t, cluster.Properties.SecurityProfile.WorkloadIdentity)
	assert.True(t, *cluster.Properties.SecurityProfile.WorkloadIdentity.Enabled)

	// Validate OIDC issuer is enabled
	assert.NotNil(t, cluster.Properties.OidcIssuerProfile)
	assert.True(t, *cluster.Properties.OidcIssuerProfile.Enabled)

	// Validate node pools
	validateNodePools(t, cluster)
}

// validateNodePools validates the node pools configuration
func validateNodePools(t *testing.T, cluster armcontainerservice.ManagedClustersClientGetResponse) {
	// Validate default/system node pool
	agentPools := cluster.Properties.AgentPoolProfiles
	require.NotNil(t, agentPools)
	require.Greater(t, len(agentPools), 0)

	// Find system pool
	var systemPool *armcontainerservice.ManagedClusterAgentPoolProfile
	for _, pool := range agentPools {
		if *pool.Mode == armcontainerservice.AgentPoolModeSystem {
			systemPool = pool
			break
		}
	}

	require.NotNil(t, systemPool, "System node pool not found")
	assert.Equal(t, "Standard_D8s_v3", string(*systemPool.VMSize))
	assert.Equal(t, int32(128), *systemPool.OSDiskSizeGB)
	assert.True(t, *systemPool.EnableAutoScaling)
	assert.Equal(t, int32(1), *systemPool.MinCount)
	assert.Equal(t, int32(5), *systemPool.MaxCount)
}

// TestAKSClusterWithExpressRoute tests the AKS cluster with ExpressRoute enabled
func TestAKSClusterWithExpressRoute(t *testing.T) {
	// Skip this test if hub VNet doesn't exist
	t.Skip("Skipping ExpressRoute test - requires existing hub infrastructure")

	uniqueID := strings.ToLower(random.UniqueId())
	testName := fmt.Sprintf("test-aks-er-%s", uniqueID)

	tempTestFolder := test_structure.CopyTerraformFolderToTemp(t, "../../", ".")

	terraformOptions := &terraform.Options{
		TerraformDir: tempTestFolder,
		Vars: map[string]interface{}{
			"location":            "East US",
			"cluster_name":        testName,
			"environment":         "test",
			"kubernetes_version":  "1.31.8",
			"system_node_count":   1,
			"spark_node_count":    1,
			"enable_expressroute": true,
		},
		NoColor: true,
	}

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "deploy", func() {
		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate", func() {
		// Validate basic cluster properties
		validateAKSCluster(t, terraformOptions)

		// Validate ExpressRoute specific outputs
		vnetPeeringEnabled := terraform.Output(t, terraformOptions, "vnet_peering_enabled")
		assert.Equal(t, "true", vnetPeeringEnabled)
	})
}
