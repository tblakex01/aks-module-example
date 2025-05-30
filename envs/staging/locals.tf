locals {
  vnet_name          = "vnet-aks-spark-staging"
  vnet_address_space = ["10.248.26.0/24"] # Staging environment range

  # Hub VNet configuration for ExpressRoute connectivity
  hub_vnet_name = "net-eastus-hub"
  hub_vnet_id   = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.hub_resource_group_name}/providers/Microsoft.Network/virtualNetworks/net-eastus-hub"

  # VM sizes for staging environment - balanced for testing
  system_vm_size = "Standard_D4s_v3" # 4 vCPU, 16 GB RAM - for system pods
  spark_vm_size  = "Standard_D8s_v3" # 8 vCPU, 32 GB RAM - for Spark staging

  subnets = {
    system = {
      name             = "subnet-aks-system"
      address_prefixes = ["10.248.26.0/26"] # /26 = 64 IPs for system nodes
    }
    spark = {
      name             = "subnet-aks-spark"
      address_prefixes = ["10.248.26.64/26"] # /26 = 64 IPs for spark nodes
    }
    endpoints = {
      name             = "subnet-endpoints"
      address_prefixes = ["10.248.26.128/27"] # /27 = 32 IPs for private endpoints
    }
  }
}