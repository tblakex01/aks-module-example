package helpers

import (
	"context"
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/containerservice/armcontainerservice/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// WaitForClusterReady waits for an AKS cluster to be in ready state
func WaitForClusterReady(t *testing.T, ctx context.Context, subscriptionID, resourceGroupName, clusterName string, maxRetries int) error {
	cred, err := azidentity.NewDefaultAzureCredential(nil)
	if err != nil {
		return err
	}

	aksClient, err := armcontainerservice.NewManagedClustersClient(subscriptionID, cred, nil)
	if err != nil {
		return err
	}

	for i := 0; i < maxRetries; i++ {
		cluster, err := aksClient.Get(ctx, resourceGroupName, clusterName, nil)
		if err != nil {
			return err
		}

		if cluster.Properties != nil && cluster.Properties.ProvisioningState != nil {
			state := *cluster.Properties.ProvisioningState
			if state == "Succeeded" {
				return nil
			}
			if state == "Failed" {
				return fmt.Errorf("cluster provisioning failed")
			}
		}

		t.Logf("Waiting for cluster to be ready... (attempt %d/%d)", i+1, maxRetries)
		time.Sleep(30 * time.Second)
	}

	return fmt.Errorf("timeout waiting for cluster to be ready")
}

// ValidateNodePool validates a node pool configuration
func ValidateNodePool(t *testing.T, nodePool *armcontainerservice.ManagedClusterAgentPoolProfile, expectedConfig NodePoolConfig) {
	require.NotNil(t, nodePool)

	// Validate VM size
	if expectedConfig.VMSize != "" {
		assert.Equal(t, expectedConfig.VMSize, string(*nodePool.VMSize))
	}

	// Validate node count
	if expectedConfig.NodeCount > 0 {
		assert.Equal(t, int32(expectedConfig.NodeCount), *nodePool.Count)
	}

	// Validate autoscaling
	if expectedConfig.EnableAutoScaling {
		assert.True(t, *nodePool.EnableAutoScaling)
		if expectedConfig.MinCount > 0 {
			assert.Equal(t, int32(expectedConfig.MinCount), *nodePool.MinCount)
		}
		if expectedConfig.MaxCount > 0 {
			assert.Equal(t, int32(expectedConfig.MaxCount), *nodePool.MaxCount)
		}
	}

	// Validate OS disk size
	if expectedConfig.OSDiskSizeGB > 0 {
		assert.Equal(t, int32(expectedConfig.OSDiskSizeGB), *nodePool.OSDiskSizeGB)
	}

	// Validate mode
	if expectedConfig.Mode != "" {
		assert.Equal(t, expectedConfig.Mode, string(*nodePool.Mode))
	}

	// Validate taints
	if len(expectedConfig.Taints) > 0 {
		require.NotNil(t, nodePool.NodeTaints)
		assert.Equal(t, len(expectedConfig.Taints), len(nodePool.NodeTaints))
		for i, expectedTaint := range expectedConfig.Taints {
			assert.Equal(t, expectedTaint, *nodePool.NodeTaints[i])
		}
	}
}

// NodePoolConfig represents expected node pool configuration
type NodePoolConfig struct {
	VMSize            string
	NodeCount         int
	EnableAutoScaling bool
	MinCount          int
	MaxCount          int
	OSDiskSizeGB      int
	Mode              string
	Taints            []string
}

// ValidateTags validates resource tags
func ValidateTags(t *testing.T, tags map[string]*string, expectedTags map[string]string) {
	for key, expectedValue := range expectedTags {
		actualValue, exists := tags[key]
		assert.True(t, exists, "Tag %s not found", key)
		if exists && actualValue != nil {
			assert.Equal(t, expectedValue, *actualValue, "Tag %s has incorrect value", key)
		}
	}
}

// ValidateSubnet validates a subnet configuration
func ValidateSubnet(t *testing.T, subnetID string, expectedAddressPrefix string) {
	// Parse subnet ID to get details
	parts := strings.Split(subnetID, "/")
	require.GreaterOrEqual(t, len(parts), 11, "Invalid subnet ID format")

	// Validate subnet name format
	subnetName := parts[10]
	assert.Contains(t, subnetName, "snet-", "Subnet name should contain 'snet-' prefix")
}

// ValidatePrivateCluster validates private cluster configuration
func ValidatePrivateCluster(t *testing.T, cluster *armcontainerservice.ManagedCluster) {
	require.NotNil(t, cluster.Properties.APIServerAccessProfile)

	// Validate private cluster is enabled
	assert.True(t, *cluster.Properties.APIServerAccessProfile.EnablePrivateCluster, "Private cluster should be enabled")

	// Validate no public FQDN
	if cluster.Properties.APIServerAccessProfile.EnablePrivateClusterPublicFQDN != nil {
		assert.False(t, *cluster.Properties.APIServerAccessProfile.EnablePrivateClusterPublicFQDN, "Public FQDN should be disabled")
	}
}

// ValidateRBAC validates RBAC configuration
func ValidateRBAC(t *testing.T, cluster *armcontainerservice.ManagedCluster) {
	require.NotNil(t, cluster.Properties.AADProfile)

	// Validate Azure RBAC is enabled
	assert.True(t, *cluster.Properties.AADProfile.EnableAzureRBAC, "Azure RBAC should be enabled")

	// Validate managed AAD is enabled
	assert.True(t, *cluster.Properties.AADProfile.Managed, "Managed AAD should be enabled")
}

// ValidateWorkloadIdentity validates workload identity configuration
func ValidateWorkloadIdentity(t *testing.T, cluster *armcontainerservice.ManagedCluster) {
	require.NotNil(t, cluster.Properties.SecurityProfile)
	require.NotNil(t, cluster.Properties.SecurityProfile.WorkloadIdentity)

	// Validate workload identity is enabled
	assert.True(t, *cluster.Properties.SecurityProfile.WorkloadIdentity.Enabled, "Workload identity should be enabled")

	// Validate OIDC issuer is enabled
	require.NotNil(t, cluster.Properties.OidcIssuerProfile)
	assert.True(t, *cluster.Properties.OidcIssuerProfile.Enabled, "OIDC issuer should be enabled")
}

// ExtractResourceInfo extracts subscription ID and resource name from Azure resource ID
func ExtractResourceInfo(resourceID string) (subscriptionID, resourceName string, err error) {
	parts := strings.Split(resourceID, "/")
	if len(parts) < 9 {
		return "", "", fmt.Errorf("invalid resource ID format")
	}

	subscriptionID = parts[2]
	resourceName = parts[len(parts)-1]
	return subscriptionID, resourceName, nil
}
