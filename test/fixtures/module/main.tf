data "azurerm_client_config" "current" {}

locals {
  base_id             = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  vnet_id             = "${local.base_id}/providers/Microsoft.Network/virtualNetworks/vnet-aks-module-test"
  system_subnet_id    = "${local.vnet_id}/subnets/subnet-aks-system"
  spark_subnet_id     = "${local.vnet_id}/subnets/subnet-aks-spark"
  private_dns_zone_id = "${local.base_id}/providers/Microsoft.Network/privateDnsZones/privatelink.${var.location}.azmk8s.io"
  workspace_id        = "${local.base_id}/providers/Microsoft.OperationalInsights/workspaces/law-aks-module-test"
}

module "aks" {
  source = "../../../modules/aks"

  cluster_name                    = var.cluster_name
  location                        = var.location
  resource_group_name             = var.resource_group_name
  kubernetes_version              = var.kubernetes_version
  sku_tier                        = var.sku_tier
  private_cluster_enabled         = var.private_cluster_enabled
  private_dns_zone_id             = var.private_cluster_enabled ? local.private_dns_zone_id : null
  network_contributor_scope_id    = local.vnet_id
  assign_network_contributor_role = true
  assign_private_dns_zone_role    = var.private_cluster_enabled

  system_node_pool = {
    name                         = "system"
    vm_size                      = "Standard_D2s_v5"
    node_count                   = 1
    subnet_id                    = local.system_subnet_id
    auto_scaling_enabled         = true
    min_count                    = 1
    max_count                    = 3
    availability_zones           = ["1", "2", "3"]
    only_critical_addons_enabled = true
    os_disk_type                 = "Managed"
    os_disk_size_gb              = 128
    ultra_ssd_enabled            = false
    node_labels = {
      nodepool = "system"
    }
  }

  node_pools = var.include_user_pool ? {
    spark = {
      name                   = "spark"
      vm_size                = "Standard_D2s_v5"
      node_count             = 1
      subnet_id              = local.spark_subnet_id
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
        workload = "spark"
      }
      node_taints = [{
        key    = "workload"
        value  = "spark"
        effect = "NoSchedule"
      }]
      tags            = { NodePool = "Spark" }
      priority        = var.node_pool_priority
      eviction_policy = var.node_pool_eviction_policy
      spot_max_price  = var.node_pool_spot_max_price
    }
  } : {}

  network_profile = {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = var.network_policy
    network_data_plane  = var.network_data_plane
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
    tenant_id          = coalesce(var.tenant_id, data.azurerm_client_config.current.tenant_id)
  }

  enable_monitoring          = var.enable_monitoring
  log_analytics_workspace_id = var.enable_monitoring ? coalesce(var.log_analytics_workspace_id, local.workspace_id) : null
  automatic_upgrade_channel  = var.automatic_upgrade_channel
  azure_policy_enabled       = true

  tags = var.tags
}
