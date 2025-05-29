module github.com/azure/aks-spark-cluster/test

go 1.21

require (
	github.com/Azure/azure-sdk-for-go/sdk/azcore v1.9.1
	github.com/Azure/azure-sdk-for-go/sdk/azidentity v1.4.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/compute/armcompute/v5 v5.4.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/containerservice/armcontainerservice/v4 v4.7.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/keyvault/armkeyvault v1.4.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/monitor/armmonitor v0.11.0
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/network/armnetwork/v5 v5.1.1
	github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/resources/armresources v1.2.0
	github.com/gruntwork-io/terratest v0.46.1
	github.com/stretchr/testify v1.8.4
)