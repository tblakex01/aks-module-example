# Example: AKS cluster optimized for Apache Spark workloads

terraform {
  required_version = ">= 1.15.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.73"
    }
  }
}

provider "azurerm" {
  resource_provider_registrations = "core"

  features {}
}

data "azurerm_client_config" "current" {}

locals {
  cluster_name = "aks-spark-prod"
  location     = "East US"
}

resource "azurerm_resource_group" "spark" {
  name     = "rg-${local.cluster_name}"
  location = local.location

  tags = {
    Environment = "Production"
    Workload    = "ApacheSpark"
  }
}

resource "azurerm_virtual_network" "spark" {
  name                = "vnet-${local.cluster_name}"
  location            = azurerm_resource_group.spark.location
  resource_group_name = azurerm_resource_group.spark.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "system" {
  name                 = "subnet-system"
  resource_group_name  = azurerm_resource_group.spark.name
  virtual_network_name = azurerm_virtual_network.spark.name
  address_prefixes     = ["10.0.2.0/26"]
}

resource "azurerm_subnet" "spark" {
  name                 = "subnet-spark"
  resource_group_name  = azurerm_resource_group.spark.name
  virtual_network_name = azurerm_virtual_network.spark.name
  address_prefixes     = ["10.0.3.0/25"]
}

resource "azurerm_log_analytics_workspace" "spark" {
  name                = "law-${local.cluster_name}"
  location            = azurerm_resource_group.spark.location
  resource_group_name = azurerm_resource_group.spark.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

module "aks_spark" {
  source = "../../modules/aks"

  cluster_name                    = local.cluster_name
  location                        = azurerm_resource_group.spark.location
  resource_group_name             = azurerm_resource_group.spark.name
  kubernetes_version              = "1.35"
  sku_tier                        = "Standard" # Production SLA
  network_contributor_scope_id    = azurerm_virtual_network.spark.id
  assign_network_contributor_role = true

  # System node pool - minimal resources for system components only
  system_node_pool = {
    name                         = "system"
    vm_size                      = "Standard_D8s_v3"
    node_count                   = 3
    subnet_id                    = azurerm_subnet.system.id
    auto_scaling_enabled         = true
    min_count                    = 1
    max_count                    = 5
    availability_zones           = ["1", "2", "3"]
    only_critical_addons_enabled = true
    os_disk_type                 = "Managed"
    os_disk_size_gb              = 128
    ultra_ssd_enabled            = false
    node_labels = {
      "nodepool-type" = "system"
      "environment"   = "production"
    }
  }

  # Spark worker nodes - memory optimized VMs
  node_pools = {
    spark = {
      name                   = "spark"
      vm_size                = "Standard_E8s_v5" # 8 vCPU, 64 GB RAM
      node_count             = 4
      subnet_id              = azurerm_subnet.spark.id
      mode                   = "User"
      auto_scaling_enabled   = true
      min_count              = 4
      max_count              = 20
      availability_zones     = ["1", "2", "3"]
      os_disk_type           = "Managed"
      os_disk_size_gb        = 256
      ultra_ssd_enabled      = false
      enable_host_encryption = false
      node_labels = {
        "workload-type" = "apache-spark"
        "compute-type"  = "memory-optimized"
      }
      node_taints = [{
        key    = "workload"
        value  = "spark"
        effect = "NoSchedule"
      }]
      tags = {
        "NodePool" = "SparkWorkers"
      }
    },
    sparkworkers_spot = {
      name                   = "sparkspot"
      vm_size                = "Standard_E8s_v5" # 8 vCPU, 64 GB RAM
      node_count             = 2                 # Start with a smaller count for spot
      subnet_id              = azurerm_subnet.spark.id
      mode                   = "User"
      auto_scaling_enabled   = true
      min_count              = 1  # Allow scaling down to 1 for spot
      max_count              = 10 # Max spot instances
      availability_zones     = ["1", "2", "3"]
      os_disk_type           = "Managed"
      os_disk_size_gb        = 256
      ultra_ssd_enabled      = false
      enable_host_encryption = false
      node_labels = {
        "workload-type" = "apache-spark-spot"
        "compute-type"  = "memory-optimized"
        "priority"      = "spot"
      }
      node_taints = [{
        key    = "workload"
        value  = "spark-spot"
        effect = "NoSchedule" # Ensure only workloads tolerant of spot eviction run here
      }]
      tags = {
        "NodePool" = "SparkWorkersSpot"
      }
      # Spot Instance Configuration
      priority        = "Spot"
      eviction_policy = "Delete" # Or "Deallocate" if you want to keep the disks
      spot_max_price  = -1       # Use Azure market price (can be a specific value like 0.1 USD/hour)
    }

    # Optional: Spark driver nodes - compute optimized (usually not on Spot)
    sparkdriver = {
      name                   = "sparkdriver"
      vm_size                = "Standard_F8s_v2" # 8 vCPU, 16 GB RAM
      node_count             = 2
      subnet_id              = azurerm_subnet.spark.id
      mode                   = "User"
      auto_scaling_enabled   = true
      min_count              = 1
      max_count              = 5
      availability_zones     = ["1", "2", "3"]
      os_disk_type           = "Managed"
      os_disk_size_gb        = 128
      ultra_ssd_enabled      = false
      enable_host_encryption = false
      node_labels = {
        "workload-type" = "apache-spark-driver"
        "compute-type"  = "compute-optimized"
      }
      node_taints = [{
        key    = "workload"
        value  = "spark-driver"
        effect = "NoSchedule"
      }]
      tags = {
        "NodePool" = "SparkDrivers"
      }
    }
  }

  # Network configuration
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
      managed_outbound_ip_count = 4 # More IPs for high throughput
      outbound_ports_allocated  = 16000
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
  log_analytics_workspace_id = azurerm_log_analytics_workspace.spark.id

  # Security and features
  azure_policy_enabled              = true
  enable_key_vault_secrets_provider = true
  workload_identity_enabled         = true
  oidc_issuer_enabled               = true

  # Maintenance window - Sunday early morning
  maintenance_window = {
    day   = "Sunday"
    hours = [2, 6]
  }

  automatic_upgrade_channel = "patch"

  tags = {
    Environment = "Production"
    Workload    = "ApacheSpark"
    CostCenter  = "DataEngineering"
  }
}

# Outputs
output "cluster_name" {
  value = module.aks_spark.cluster_name
}

output "cluster_id" {
  value = module.aks_spark.cluster_id
}

output "node_pools" {
  value = module.aks_spark.node_pools
}

output "connect_command" {
  value = "az aks get-credentials --resource-group ${azurerm_resource_group.spark.name} --name ${module.aks_spark.cluster_name}"
}
