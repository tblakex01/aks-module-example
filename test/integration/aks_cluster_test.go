package test

import (
	"context"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/containerservice/armcontainerservice/v4"
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/network/armnetwork/v7"
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/operationalinsights/armoperationalinsights"
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/privatedns/armprivatedns"
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/resources/armresources"
	"github.com/azure/aks-spark-cluster/test/helpers"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestAKSIntegrationDeployment(t *testing.T) {
	helpers.RequireIntegration(t)

	uniqueID := strings.ToLower(random.UniqueID())
	clusterName := "aks-it-" + uniqueID
	resourceGroupName := "rg-" + clusterName
	repoCopy := test_structure.CopyTerraformFolderToTemp(t, "../../", ".")
	fixtureDir := filepath.Join(repoCopy, "test", "fixtures", "integration")

	terraformOptions := helpers.GetTerraformOptions(fixtureDir, map[string]interface{}{
		"resource_group_name": resourceGroupName,
		"cluster_name":        clusterName,
		"tags": map[string]string{
			"Environment": "test",
			"Purpose":     "terratest",
			"Temporary":   "true",
			"TestRun":     uniqueID,
		},
	})

	deployCtx, cancelDeploy := context.WithTimeout(context.Background(), 90*time.Minute)
	defer cancelDeploy()
	defer func() {
		destroyCtx, cancelDestroy := context.WithTimeout(context.Background(), 45*time.Minute)
		defer cancelDestroy()
		terraform.DestroyContext(t, destroyCtx, terraformOptions)
	}()

	terraform.InitAndApplyContext(t, deployCtx, terraformOptions)

	validateDeployment(t, terraformOptions)
}

func validateDeployment(t *testing.T, terraformOptions *terraform.Options) {
	t.Helper()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	cred, err := azidentity.NewDefaultAzureCredential(nil)
	require.NoError(t, err)

	resourceGroupName := terraform.OutputContext(t, ctx, terraformOptions, "resource_group_name")
	clusterName := terraform.OutputContext(t, ctx, terraformOptions, "cluster_name")
	clusterID := terraform.OutputContext(t, ctx, terraformOptions, "cluster_id")
	vnetID := terraform.OutputContext(t, ctx, terraformOptions, "vnet_id")
	systemSubnetID := terraform.OutputContext(t, ctx, terraformOptions, "system_subnet_id")
	privateDNSZoneID := terraform.OutputContext(t, ctx, terraformOptions, "private_dns_zone_id")
	logAnalyticsWorkspaceID := terraform.OutputContext(t, ctx, terraformOptions, "log_analytics_workspace_id")

	subscriptionID := strings.Split(clusterID, "/")[2]

	validateResourceGroup(t, ctx, cred, subscriptionID, resourceGroupName)
	validateCluster(t, ctx, cred, subscriptionID, resourceGroupName, clusterName)
	validateNetwork(t, ctx, cred, subscriptionID, resourceGroupName, vnetID, systemSubnetID)
	validatePrivateDNS(t, ctx, cred, subscriptionID, resourceGroupName, privateDNSZoneID)
	validateMonitoring(t, ctx, cred, subscriptionID, resourceGroupName, logAnalyticsWorkspaceID)
}

func validateResourceGroup(t *testing.T, ctx context.Context, cred *azidentity.DefaultAzureCredential, subscriptionID, resourceGroupName string) {
	t.Helper()

	client, err := armresources.NewResourceGroupsClient(subscriptionID, cred, nil)
	require.NoError(t, err)

	rg, err := client.Get(ctx, resourceGroupName, nil)
	require.NoError(t, err)
	require.NotNil(t, rg.Name)
	assert.Equal(t, resourceGroupName, *rg.Name)
	require.NotNil(t, rg.Tags)
	assert.Equal(t, "terratest", *rg.Tags["Purpose"])
	assert.Equal(t, "true", *rg.Tags["Temporary"])
}

func validateCluster(t *testing.T, ctx context.Context, cred *azidentity.DefaultAzureCredential, subscriptionID, resourceGroupName, clusterName string) {
	t.Helper()

	client, err := armcontainerservice.NewManagedClustersClient(subscriptionID, cred, nil)
	require.NoError(t, err)

	cluster, err := client.Get(ctx, resourceGroupName, clusterName, nil)
	require.NoError(t, err)
	require.NotNil(t, cluster.Properties)
	require.NotNil(t, cluster.Properties.APIServerAccessProfile)
	require.NotNil(t, cluster.Identity)

	assert.Equal(t, clusterName, *cluster.Name)
	assert.Equal(t, "Succeeded", string(*cluster.Properties.ProvisioningState))
	assert.True(t, *cluster.Properties.APIServerAccessProfile.EnablePrivateCluster)
	assert.Equal(t, armcontainerservice.ResourceIdentityTypeUserAssigned, *cluster.Identity.Type)
	assert.Equal(t, armcontainerservice.ManagedClusterSKUTierFree, *cluster.SKU.Tier)

	require.NotNil(t, cluster.Properties.NetworkProfile)
	assert.Equal(t, armcontainerservice.NetworkPluginAzure, *cluster.Properties.NetworkProfile.NetworkPlugin)
	assert.Equal(t, armcontainerservice.NetworkPolicyCilium, *cluster.Properties.NetworkProfile.NetworkPolicy)
	assert.Equal(t, armcontainerservice.NetworkDataplaneCilium, *cluster.Properties.NetworkProfile.NetworkDataplane)
}

func validateNetwork(t *testing.T, ctx context.Context, cred *azidentity.DefaultAzureCredential, subscriptionID, resourceGroupName, vnetID, systemSubnetID string) {
	t.Helper()

	vnetClient, err := armnetwork.NewVirtualNetworksClient(subscriptionID, cred, nil)
	require.NoError(t, err)

	vnetName := lastIDSegment(vnetID)
	vnet, err := vnetClient.Get(ctx, resourceGroupName, vnetName, nil)
	require.NoError(t, err)
	require.NotNil(t, vnet.Properties)
	require.NotNil(t, vnet.Properties.AddressSpace)
	assert.Contains(t, pointerValues(vnet.Properties.AddressSpace.AddressPrefixes), "10.42.0.0/16")

	systemSubnetName := lastIDSegment(systemSubnetID)
	subnetClient, err := armnetwork.NewSubnetsClient(subscriptionID, cred, nil)
	require.NoError(t, err)

	subnet, err := subnetClient.Get(ctx, resourceGroupName, vnetName, systemSubnetName, nil)
	require.NoError(t, err)
	require.NotNil(t, subnet.Properties)
	assert.Equal(t, "10.42.0.0/24", *subnet.Properties.AddressPrefix)
}

func validatePrivateDNS(t *testing.T, ctx context.Context, cred *azidentity.DefaultAzureCredential, subscriptionID, resourceGroupName, privateDNSZoneID string) {
	t.Helper()

	client, err := armprivatedns.NewPrivateZonesClient(subscriptionID, cred, nil)
	require.NoError(t, err)

	zoneName := lastIDSegment(privateDNSZoneID)
	zone, err := client.Get(ctx, resourceGroupName, zoneName, nil)
	require.NoError(t, err)
	require.NotNil(t, zone.Name)
	assert.Contains(t, *zone.Name, "privatelink.")
	assert.Contains(t, *zone.Name, "azmk8s.io")
}

func validateMonitoring(t *testing.T, ctx context.Context, cred *azidentity.DefaultAzureCredential, subscriptionID, resourceGroupName, workspaceID string) {
	t.Helper()

	client, err := armoperationalinsights.NewWorkspacesClient(subscriptionID, cred, nil)
	require.NoError(t, err)

	workspaceName := lastIDSegment(workspaceID)
	workspace, err := client.Get(ctx, resourceGroupName, workspaceName, nil)
	require.NoError(t, err)
	require.NotNil(t, workspace.Properties)
	require.NotNil(t, workspace.Properties.SKU)
	assert.Equal(t, armoperationalinsights.WorkspaceSKUNameEnumPerGB2018, *workspace.Properties.SKU.Name)
	assert.Equal(t, int32(30), *workspace.Properties.RetentionInDays)
}

func lastIDSegment(resourceID string) string {
	parts := strings.Split(resourceID, "/")
	return parts[len(parts)-1]
}

func pointerValues(values []*string) []string {
	result := make([]string, 0, len(values))
	for _, value := range values {
		if value != nil {
			result = append(result, *value)
		}
	}
	return result
}
