package helpers

import (
	"testing"

	"github.com/Azure/azure-sdk-for-go/sdk/azcore/to"
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/containerservice/armcontainerservice/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestValidateNodePoolMatchesExpectedProfile(t *testing.T) {
	nodePool := &armcontainerservice.ManagedClusterAgentPoolProfile{
		Name:              to.Ptr("system"),
		VMSize:            to.Ptr("Standard_D4s_v5"),
		Count:             to.Ptr[int32](3),
		EnableAutoScaling: to.Ptr(true),
		MinCount:          to.Ptr[int32](2),
		MaxCount:          to.Ptr[int32](5),
		OSDiskSizeGB:      to.Ptr[int32](128),
		Mode:              to.Ptr(armcontainerservice.AgentPoolModeSystem),
		NodeTaints:        []*string{to.Ptr("workload=spark:NoSchedule")},
	}

	ValidateNodePool(t, nodePool, NodePoolConfig{
		VMSize:            "Standard_D4s_v5",
		NodeCount:         3,
		EnableAutoScaling: true,
		MinCount:          2,
		MaxCount:          5,
		OSDiskSizeGB:      128,
		Mode:              string(armcontainerservice.AgentPoolModeSystem),
		Taints:            []string{"workload=spark:NoSchedule"},
	})
}

func TestValidateClusterSecuritySettings(t *testing.T) {
	cluster := &armcontainerservice.ManagedCluster{
		Properties: &armcontainerservice.ManagedClusterProperties{
			APIServerAccessProfile: &armcontainerservice.ManagedClusterAPIServerAccessProfile{
				EnablePrivateCluster:           to.Ptr(true),
				EnablePrivateClusterPublicFQDN: to.Ptr(false),
			},
			AADProfile: &armcontainerservice.ManagedClusterAADProfile{
				EnableAzureRBAC: to.Ptr(true),
				Managed:         to.Ptr(true),
			},
			SecurityProfile: &armcontainerservice.ManagedClusterSecurityProfile{
				WorkloadIdentity: &armcontainerservice.ManagedClusterSecurityProfileWorkloadIdentity{
					Enabled: to.Ptr(true),
				},
			},
			OidcIssuerProfile: &armcontainerservice.ManagedClusterOIDCIssuerProfile{
				Enabled: to.Ptr(true),
			},
		},
	}

	ValidatePrivateCluster(t, cluster)
	ValidateRBAC(t, cluster)
	ValidateWorkloadIdentity(t, cluster)
}

func TestValidateTagsSubnetAndResourceInfo(t *testing.T) {
	ValidateTags(t, map[string]*string{
		"Environment": to.Ptr("test"),
		"Purpose":     to.Ptr("terratest"),
	}, map[string]string{
		"Environment": "test",
		"Purpose":     "terratest",
	})

	ValidateSubnet(t, "/subscriptions/sub/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet/subnets/snet-system", "10.0.1.0/24")

	subscriptionID, resourceName, err := ExtractResourceInfo("/subscriptions/sub/resourceGroups/rg/providers/Microsoft.ContainerService/managedClusters/aks")
	require.NoError(t, err)
	assert.Equal(t, "sub", subscriptionID)
	assert.Equal(t, "aks", resourceName)

	_, _, err = ExtractResourceInfo("/subscriptions/sub")
	require.Error(t, err)
}
