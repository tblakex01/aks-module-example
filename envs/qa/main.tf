# Resource Group
resource "azurerm_resource_group" "aks" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Virtual Network
resource "azurerm_virtual_network" "aks" {
  name                = local.vnet_name
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  address_space       = local.vnet_address_space
  tags                = var.tags
}

# Subnets
resource "azurerm_subnet" "system" {
  name                 = local.subnets.system.name
  resource_group_name  = azurerm_resource_group.aks.name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = local.subnets.system.address_prefixes
}

resource "azurerm_subnet" "spark" {
  name                 = local.subnets.spark.name
  resource_group_name  = azurerm_resource_group.aks.name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = local.subnets.spark.address_prefixes
}

resource "azurerm_subnet" "endpoints" {
  name                 = local.subnets.endpoints.name
  resource_group_name  = azurerm_resource_group.aks.name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = local.subnets.endpoints.address_prefixes
}

# Network Security Group
resource "azurerm_network_security_group" "aks" {
  name                = "nsg-${local.vnet_name}"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name

  security_rule {
    name                       = "AllowVnetInBound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowAzureLoadBalancerInBound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPSFromOnPrem"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowOracleFromOnPrem"
    priority                   = 210
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["1521", "1522"]
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHubVNetInBound"
    priority                   = 220
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInBound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

# NSG Associations
resource "azurerm_subnet_network_security_group_association" "system" {
  subnet_id                 = azurerm_subnet.system.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_subnet_network_security_group_association" "spark" {
  subnet_id                 = azurerm_subnet.spark.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_subnet_network_security_group_association" "endpoints" {
  subnet_id                 = azurerm_subnet.endpoints.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

# Private DNS Zone for AKS
resource "azurerm_private_dns_zone" "aks" {
  name                = "privatelink.${replace(lower(var.location), " ", "")}.azmk8s.io"
  resource_group_name = azurerm_resource_group.aks.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "aks" {
  name                  = "vnet-link-spoke"
  resource_group_name   = azurerm_resource_group.aks.name
  private_dns_zone_name = azurerm_private_dns_zone.aks.name
  virtual_network_id    = azurerm_virtual_network.aks.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  count                 = var.enable_hub_peering ? 1 : 0
  name                  = "vnet-link-hub"
  resource_group_name   = azurerm_resource_group.aks.name
  private_dns_zone_name = azurerm_private_dns_zone.aks.name
  virtual_network_id    = data.azurerm_virtual_network.hub[0].id
  registration_enabled  = false
  tags                  = var.tags
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "aks" {
  name                = "law-${var.cluster_name}"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

resource "azurerm_log_analytics_solution" "aks" {
  solution_name         = "ContainerInsights"
  location              = azurerm_resource_group.aks.location
  resource_group_name   = azurerm_resource_group.aks.name
  workspace_resource_id = azurerm_log_analytics_workspace.aks.id
  workspace_name        = azurerm_log_analytics_workspace.aks.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }

  tags = var.tags
}

# Key Vault
resource "azurerm_key_vault" "aks" {
  name                       = "kv-${substr(replace(var.cluster_name, "-", ""), 0, 17)}"
  location                   = azurerm_resource_group.aks.location
  resource_group_name        = azurerm_resource_group.aks.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 90
  purge_protection_enabled   = true

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get", "List", "Update", "Create", "Import", "Delete", "Recover", "Backup", "Restore"
    ]

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore"
    ]
  }

  tags = var.tags
}

# AKS Cluster using the module
module "aks" {
  source = "../../modules/aks"

  cluster_name        = var.cluster_name
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier

  # System node pool configuration
  system_node_pool = {
    name                         = "system"
    vm_size                      = local.system_vm_size
    node_count                   = var.node_count
    subnet_id                    = azurerm_subnet.system.id
    enable_auto_scaling          = true
    min_count                    = 1
    max_count                    = 10
    availability_zones           = ["1", "2", "3"]
    only_critical_addons_enabled = true
    os_disk_type                 = "Managed"
    os_disk_size_gb              = 128
    ultra_ssd_enabled            = false
    node_labels = {
      "nodepool-type"                         = "system"
      "environment"                           = "qa"
      "nodepoolos"                            = "linux"
      "kubernetes.azure.com/scalesetpriority" = "regular"
    }
  }

  # Additional node pools
  node_pools = {
    spark = {
      name                   = "spark"
      vm_size                = local.spark_vm_size
      node_count             = var.node_count
      subnet_id              = azurerm_subnet.spark.id
      mode                   = "User"
      enable_auto_scaling    = true
      min_count              = 1
      max_count              = 10
      availability_zones     = ["1", "2", "3"]
      os_disk_type           = "Managed"
      os_disk_size_gb        = 256
      ultra_ssd_enabled      = false
      enable_host_encryption = false
      node_labels = {
        "nodepool-type" = "spark"
        "environment"   = "qa"
        "workload-type" = "apache-spark"
        "compute-type"  = "general-purpose"
      }
      node_taints = [{
        key    = "workload"
        value  = "spark"
        effect = "NoSchedule"
      }]
      tags = {
        "NodePool" = "Spark"
      }
    }
  }

  # Network configuration
  network_profile = {
    network_plugin = "azure"
    network_policy = "azure"
    dns_service_ip = "172.16.0.10"
    service_cidr   = "172.16.0.0/16"
    outbound_type  = "loadBalancer"
    load_balancer_profile = {
      managed_outbound_ip_count = 2
      outbound_ports_allocated  = 8000
      idle_timeout_in_minutes   = 30
    }
  }

  # Azure AD RBAC
  azure_ad_rbac = {
    managed            = true
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }

  # Monitoring
  enable_monitoring          = true
  log_analytics_workspace_id = azurerm_log_analytics_workspace.aks.id

  # Maintenance window
  maintenance_window = {
    day   = "Sunday"
    hours = [2, 6]
  }

  tags = var.tags

  depends_on = [
    azurerm_subnet.system,
    azurerm_subnet.spark,
    azurerm_private_dns_zone.aks,
    azurerm_log_analytics_workspace.aks
  ]
}

# Key Vault access policy for AKS
resource "azurerm_key_vault_access_policy" "aks" {
  key_vault_id = azurerm_key_vault.aks.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = module.aks.key_vault_secrets_provider_identity.object_id

  secret_permissions = [
    "Get", "List"
  ]
}