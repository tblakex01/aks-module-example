resource "azurerm_kubernetes_cluster" "aks" {
  name                       = var.cluster_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  dns_prefix_private_cluster = "${var.cluster_name}-dns"
  kubernetes_version         = var.kubernetes_version

  private_cluster_enabled             = var.private_cluster_enabled
  private_cluster_public_fqdn_enabled = var.private_cluster_public_fqdn_enabled

  sku_tier = var.sku_tier

  default_node_pool {
    name           = var.system_node_pool.name
    node_count     = var.system_node_pool.enable_auto_scaling ? null : var.system_node_pool.node_count
    vm_size        = var.system_node_pool.vm_size
    vnet_subnet_id = var.system_node_pool.subnet_id
    type           = "VirtualMachineScaleSets"
    min_count      = var.system_node_pool.enable_auto_scaling ? var.system_node_pool.min_count : null
    max_count      = var.system_node_pool.enable_auto_scaling ? var.system_node_pool.max_count : null
    zones          = var.system_node_pool.availability_zones

    only_critical_addons_enabled = var.system_node_pool.only_critical_addons_enabled

    os_disk_type    = var.system_node_pool.os_disk_type
    os_disk_size_gb = var.system_node_pool.os_disk_size_gb

    ultra_ssd_enabled = var.system_node_pool.ultra_ssd_enabled

    node_labels = var.system_node_pool.node_labels

    tags = var.tags
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = var.network_profile.network_plugin
    network_policy    = var.network_profile.network_policy
    dns_service_ip    = var.network_profile.dns_service_ip
    service_cidr      = var.network_profile.service_cidr
    load_balancer_sku = "standard"
    outbound_type     = var.network_profile.outbound_type

    dynamic "load_balancer_profile" {
      for_each = var.network_profile.load_balancer_profile != null ? [var.network_profile.load_balancer_profile] : []
      content {
        managed_outbound_ip_count = load_balancer_profile.value.managed_outbound_ip_count
        outbound_ports_allocated  = load_balancer_profile.value.outbound_ports_allocated
        idle_timeout_in_minutes   = load_balancer_profile.value.idle_timeout_in_minutes
      }
    }
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = var.azure_ad_rbac.azure_rbac_enabled
    tenant_id          = var.azure_ad_rbac.tenant_id
  }

  dynamic "oms_agent" {
    for_each = var.enable_monitoring && var.log_analytics_workspace_id != null ? [1] : []
    content {
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }
  }

  azure_policy_enabled = var.azure_policy_enabled

  dynamic "key_vault_secrets_provider" {
    for_each = var.enable_key_vault_secrets_provider ? [1] : []
    content {
      secret_rotation_enabled  = var.key_vault_secrets_provider_config.secret_rotation_enabled
      secret_rotation_interval = var.key_vault_secrets_provider_config.secret_rotation_interval
    }
  }

  workload_identity_enabled = var.workload_identity_enabled
  oidc_issuer_enabled       = var.oidc_issuer_enabled

  dynamic "maintenance_window" {
    for_each = var.maintenance_window != null ? [var.maintenance_window] : []
    content {
      allowed {
        day   = maintenance_window.value.day
        hours = maintenance_window.value.hours
      }
    }
  }

  tags = var.tags
}

resource "azurerm_kubernetes_cluster_node_pool" "additional" {
  for_each = var.node_pools

  name                  = each.value.name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = each.value.vm_size
  node_count            = each.value.enable_auto_scaling ? null : each.value.node_count
  vnet_subnet_id        = each.value.subnet_id

  mode = each.value.mode

  min_count = each.value.enable_auto_scaling ? each.value.min_count : null
  max_count = each.value.enable_auto_scaling ? each.value.max_count : null
  zones     = each.value.availability_zones

  os_disk_type    = each.value.os_disk_type
  os_disk_size_gb = each.value.os_disk_size_gb

  ultra_ssd_enabled       = each.value.ultra_ssd_enabled
  host_encryption_enabled = each.value.enable_host_encryption

  node_labels = each.value.node_labels

  node_taints = [
    for taint in coalesce(each.value.node_taints, []) : "${taint.key}=${taint.value}:${taint.effect}"
  ]

  priority        = each.value.priority
  eviction_policy = each.value.priority == "Spot" ? each.value.eviction_policy : null
  spot_max_price  = each.value.priority == "Spot" ? each.value.spot_max_price : null

  tags = merge(var.tags, each.value.tags)
}
