locals {
  vnet_name          = "vnet-aks-spark-spoke"
  vnet_address_space = ["10.248.27.0/24"] # Using assigned range to avoid overlap

  # Hub VNet configuration for ExpressRoute connectivity
  hub_vnet_name = "net-eastus-hub"
  hub_vnet_id   = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.hub_resource_group_name}/providers/Microsoft.Network/virtualNetworks/net-eastus-hub"

  # VM sizes optimized for Apache Spark
  system_vm_size = "Standard_D8s_v3" # 8 vCPU, 32 GB RAM - for system pods
  spark_vm_size  = "Standard_D8s_v3" # 8 vCPU, 32 GB RAM - general purpose for Spark

  subnets = {
    system = {
      name             = "subnet-aks-system"
      address_prefixes = ["10.248.27.0/26"] # /26 = 64 IPs for system nodes
    }
    spark = {
      name             = "subnet-aks-spark"
      address_prefixes = ["10.248.27.64/26"] # /26 = 64 IPs for spark nodes
    }
    endpoints = {
      name             = "subnet-endpoints"
      address_prefixes = ["10.248.27.128/27"] # /27 = 32 IPs for private endpoints
    }
  }
}