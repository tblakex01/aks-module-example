data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "test" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "test" {
  name                = "vnet-${var.cluster_name}"
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name
  address_space       = ["10.42.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "system" {
  name                 = "subnet-aks-system"
  resource_group_name  = azurerm_resource_group.test.name
  virtual_network_name = azurerm_virtual_network.test.name
  address_prefixes     = ["10.42.0.0/24"]
}

resource "azurerm_subnet" "spark" {
  name                 = "subnet-aks-spark"
  resource_group_name  = azurerm_resource_group.test.name
  virtual_network_name = azurerm_virtual_network.test.name
  address_prefixes     = ["10.42.1.0/24"]
}

resource "azurerm_private_dns_zone" "aks" {
  name                = "privatelink.${replace(lower(var.location), " ", "")}.azmk8s.io"
  resource_group_name = azurerm_resource_group.test.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "aks" {
  name                  = "vnet-link-${var.cluster_name}"
  resource_group_name   = azurerm_resource_group.test.name
  private_dns_zone_name = azurerm_private_dns_zone.aks.name
  virtual_network_id    = azurerm_virtual_network.test.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_log_analytics_workspace" "test" {
  name                = "law-${var.cluster_name}"
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

module "aks" {
  source = "../../../modules/aks"

  cluster_name                    = var.cluster_name
  location                        = azurerm_resource_group.test.location
  resource_group_name             = azurerm_resource_group.test.name
  kubernetes_version              = var.kubernetes_version
  sku_tier                        = "Free"
  private_dns_zone_id             = azurerm_private_dns_zone.aks.id
  network_contributor_scope_id    = azurerm_virtual_network.test.id
  assign_network_contributor_role = true
  assign_private_dns_zone_role    = true

  system_node_pool = {
    name                         = "system"
    vm_size                      = "Standard_D2s_v5"
    node_count                   = 1
    subnet_id                    = azurerm_subnet.system.id
    auto_scaling_enabled         = true
    min_count                    = 1
    max_count                    = 2
    availability_zones           = []
    only_critical_addons_enabled = true
    os_disk_type                 = "Managed"
    os_disk_size_gb              = 128
    ultra_ssd_enabled            = false
    node_labels = {
      nodepool = "system"
    }
  }

  network_profile = {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_data_plane  = "cilium"
    dns_service_ip      = "172.16.0.10"
    service_cidr        = "172.16.0.0/16"
    pod_cidr            = "10.244.0.0/16"
    outbound_type       = "loadBalancer"
    load_balancer_profile = {
      managed_outbound_ip_count = 1
      outbound_ports_allocated  = 4000
      idle_timeout_in_minutes   = 30
    }
  }

  azure_ad_rbac = {
    managed            = true
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }

  enable_monitoring          = true
  log_analytics_workspace_id = azurerm_log_analytics_workspace.test.id
  azure_policy_enabled       = true
  automatic_upgrade_channel  = "patch"
  tags                       = var.tags

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.aks
  ]
}
