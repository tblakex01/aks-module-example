package test

import (
	"context"
	"strings"
	"testing"

	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/keyvault/armkeyvault"
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/network/armnetwork/v5"
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/privatedns/armprivatedns"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestNetworkConfiguration tests the network configuration
func TestNetworkConfiguration(t *testing.T) {
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

	// Validate network configuration
	validateNetworkConfiguration(t, terraformOptions)
}

// validateNetworkConfiguration validates the network setup
func validateNetworkConfiguration(t *testing.T, terraformOptions *terraform.Options) {
	// Get outputs
	resourceGroupName := terraform.Output(t, terraformOptions, "resource_group_name")
	vnetID := terraform.Output(t, terraformOptions, "vnet_id")
	systemSubnetID := terraform.Output(t, terraformOptions, "system_subnet_id")
	sparkSubnetID := terraform.Output(t, terraformOptions, "spark_subnet_id")

	// Create Azure clients
	ctx := context.Background()
	cred, err := azidentity.NewDefaultAzureCredential(nil)
	require.NoError(t, err)

	// Get subscription ID from vnet ID
	subscriptionID := strings.Split(vnetID, "/")[2]

	// Create network client
	vnetClient, err := armnetwork.NewVirtualNetworksClient(subscriptionID, cred, nil)
	require.NoError(t, err)

	// Get VNet name from ID
	vnetName := strings.Split(vnetID, "/")[8]

	// Validate VNet
	vnet, err := vnetClient.Get(ctx, resourceGroupName, vnetName, nil)
	require.NoError(t, err)
	assert.NotNil(t, vnet)

	// Validate address space
	assert.Contains(t, vnet.Properties.AddressSpace.AddressPrefixes, "10.248.27.0/24")

	// Validate subnets
	subnets := vnet.Properties.Subnets
	require.NotNil(t, subnets)
	require.GreaterOrEqual(t, len(subnets), 3)

	// Validate subnet configurations
	validateSubnets(t, subnets, systemSubnetID, sparkSubnetID)

	// Validate NSG
	validateNetworkSecurityGroup(t, ctx, cred, subscriptionID, resourceGroupName)
}

// validateSubnets validates subnet configurations
func validateSubnets(t *testing.T, subnets []*armnetwork.Subnet, systemSubnetID, sparkSubnetID string) {
	systemSubnetName := strings.Split(systemSubnetID, "/")[10]
	sparkSubnetName := strings.Split(sparkSubnetID, "/")[10]

	for _, subnet := range subnets {
		switch *subnet.Name {
		case systemSubnetName:
			assert.Equal(t, "10.248.27.0/26", *subnet.Properties.AddressPrefix)
		case sparkSubnetName:
			assert.Equal(t, "10.248.27.64/26", *subnet.Properties.AddressPrefix)
		case "snet-aks-endpoints":
			assert.Equal(t, "10.248.27.128/27", *subnet.Properties.AddressPrefix)
		}
	}
}

// validateNetworkSecurityGroup validates NSG rules
func validateNetworkSecurityGroup(t *testing.T, ctx context.Context, cred *azidentity.DefaultAzureCredential, subscriptionID, resourceGroupName string) {
	nsgClient, err := armnetwork.NewSecurityGroupsClient(subscriptionID, cred, nil)
	require.NoError(t, err)

	// List NSGs in resource group
	pager := nsgClient.NewListPager(resourceGroupName, nil)

	var nsg *armnetwork.SecurityGroup
	for pager.More() {
		page, err := pager.NextPage(ctx)
		require.NoError(t, err)

		if len(page.Value) > 0 {
			nsg = page.Value[0]
			break
		}
	}

	require.NotNil(t, nsg, "No NSG found in resource group")

	// Validate security rules
	rules := nsg.Properties.SecurityRules
	require.NotNil(t, rules)
	require.Greater(t, len(rules), 0)

	// Check for specific rules
	hasHTTPSRule := false
	hasDenyAllRule := false

	for _, rule := range rules {
		if *rule.Properties.DestinationPortRange == "443" && *rule.Properties.Access == armnetwork.SecurityRuleAccessAllow {
			hasHTTPSRule = true
		}
		if *rule.Name == "DenyAllInbound" && *rule.Properties.Access == armnetwork.SecurityRuleAccessDeny {
			hasDenyAllRule = true
		}
	}

	assert.True(t, hasHTTPSRule, "HTTPS allow rule not found")
	assert.True(t, hasDenyAllRule, "Deny all inbound rule not found")
}

// TestKeyVaultConfiguration tests Key Vault setup
func TestKeyVaultConfiguration(t *testing.T) {
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

	// Validate Key Vault configuration
	validateKeyVault(t, terraformOptions)
}

// validateKeyVault validates Key Vault configuration
func validateKeyVault(t *testing.T, terraformOptions *terraform.Options) {
	// Get outputs
	resourceGroupName := terraform.Output(t, terraformOptions, "resource_group_name")
	keyVaultID := terraform.Output(t, terraformOptions, "key_vault_id")

	// Create Azure clients
	ctx := context.Background()
	cred, err := azidentity.NewDefaultAzureCredential(nil)
	require.NoError(t, err)

	// Get subscription ID and Key Vault name from ID
	parts := strings.Split(keyVaultID, "/")
	subscriptionID := parts[2]
	keyVaultName := parts[8]

	// Create Key Vault client
	kvClient, err := armkeyvault.NewVaultsClient(subscriptionID, cred, nil)
	require.NoError(t, err)

	// Get Key Vault
	kv, err := kvClient.Get(ctx, resourceGroupName, keyVaultName, nil)
	require.NoError(t, err)
	assert.NotNil(t, kv)

	// Validate Key Vault properties
	assert.Equal(t, armkeyvault.SKUNameStandard, *kv.Properties.SKU.Name)
	assert.True(t, *kv.Properties.EnableSoftDelete)
	assert.True(t, *kv.Properties.EnablePurgeProtection)
	assert.Equal(t, int32(90), *kv.Properties.SoftDeleteRetentionInDays)

	// Validate RBAC is enabled
	assert.True(t, *kv.Properties.EnableRbacAuthorization)
}

// TestPrivateDNSZone tests Private DNS Zone configuration
func TestPrivateDNSZone(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../",
		Vars: map[string]interface{}{
			"environment": "test",
			"location":    "eastus", // Ensure consistent location
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Get outputs
	resourceGroupName := terraform.Output(t, terraformOptions, "resource_group_name")
	privateDNSZoneID := terraform.Output(t, terraformOptions, "private_dns_zone_id")

	// Create Azure clients
	ctx := context.Background()
	cred, err := azidentity.NewDefaultAzureCredential(nil)
	require.NoError(t, err)

	// Get subscription ID from DNS zone ID
	subscriptionID := strings.Split(privateDNSZoneID, "/")[2]

	// Create Private DNS Zone client
	dnsClient, err := armprivatedns.NewPrivateZonesClient(subscriptionID, cred, nil)
	require.NoError(t, err)

	// Get DNS zone name from ID
	dnsZoneName := strings.Split(privateDNSZoneID, "/")[8]

	// Get Private DNS Zone
	dnsZone, err := dnsClient.Get(ctx, resourceGroupName, dnsZoneName, nil)
	require.NoError(t, err)
	assert.NotNil(t, dnsZone)

	// Validate the zone name contains the expected pattern
	assert.Contains(t, *dnsZone.Name, "privatelink")
	assert.Contains(t, *dnsZone.Name, "azmk8s.io")
}
