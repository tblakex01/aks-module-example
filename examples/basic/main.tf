# Example: Basic AKS cluster using the module

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "example" {
  name     = "rg-aks-example"
  location = "East US"
}

resource "azurerm_virtual_network" "example" {
  name                = "vnet-aks-example"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "system" {
  name                 = "subnet-system"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.2.0/26"]
}

module "aks" {
  source = "../../modules/aks"

  cluster_name        = "aks-example-cluster"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  kubernetes_version  = "1.28.5"

  system_node_pool = {
    name                         = "system"
    vm_size                      = "Standard_D4s_v3"
    node_count                   = 3
    subnet_id                    = azurerm_subnet.system.id
    enable_auto_scaling          = true
    min_count                    = 1
    max_count                    = 5
    availability_zones           = ["1", "2", "3"]
    only_critical_addons_enabled = true
    os_disk_type                 = "Managed"
    os_disk_size_gb              = 128
    ultra_ssd_enabled            = false
    node_labels = {
      "nodepool-type" = "system"
    }
  }

  network_profile = {
    network_plugin = "azure"
    network_policy = "azure"
    dns_service_ip = "172.16.0.10"
    service_cidr   = "172.16.0.0/16"
    outbound_type  = "loadBalancer"
  }

  azure_ad_rbac = {
    managed            = true
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }

  enable_monitoring = false # Set to true if you have a Log Analytics workspace

  tags = {
    Environment = "Example"
    ManagedBy   = "Terraform"
  }
}

output "cluster_name" {
  value = module.aks.cluster_name
}

output "cluster_id" {
  value = module.aks.cluster_id
}