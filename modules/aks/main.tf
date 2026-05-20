locals {
  created_private_dns_zone_id            = var.create_network_resources && var.private_cluster_enabled ? azurerm_private_dns_zone.aks[0].id : null
  effective_private_dns_zone_id          = var.private_cluster_enabled ? try(coalesce(var.private_dns_zone_id, local.created_private_dns_zone_id), null) : null
  created_network_contributor_scope_id   = var.create_network_resources ? azurerm_virtual_network.aks[0].id : null
  effective_network_contributor_scope_id = try(coalesce(var.network_contributor_scope_id, local.created_network_contributor_scope_id), null)
  created_log_analytics_workspace_id     = var.create_monitoring_resources ? azurerm_log_analytics_workspace.aks[0].id : null
  effective_log_analytics_workspace_id   = var.enable_monitoring ? try(coalesce(var.log_analytics_workspace_id, local.created_log_analytics_workspace_id), null) : null
}

resource "azurerm_user_assigned_identity" "aks" {
  name                = "id-${var.cluster_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_role_assignment" "aks_network_contributor" {
  count                            = var.create_network_resources || var.assign_network_contributor_role ? 1 : 0
  scope                            = local.effective_network_contributor_scope_id
  role_definition_name             = "Network Contributor"
  principal_id                     = azurerm_user_assigned_identity.aks.principal_id
  skip_service_principal_aad_check = true

  lifecycle {
    precondition {
      condition     = local.effective_network_contributor_scope_id != null
      error_message = "network_contributor_scope_id is required when assign_network_contributor_role is true and create_network_resources is false."
    }
  }
}

resource "azurerm_role_assignment" "aks_private_dns_zone_contributor" {
  count                            = var.private_cluster_enabled && (var.create_network_resources || var.assign_private_dns_zone_role) ? 1 : 0
  scope                            = local.effective_private_dns_zone_id
  role_definition_name             = "Private DNS Zone Contributor"
  principal_id                     = azurerm_user_assigned_identity.aks.principal_id
  skip_service_principal_aad_check = true

  lifecycle {
    precondition {
      condition     = local.effective_private_dns_zone_id != null
      error_message = "private_dns_zone_id is required when assign_private_dns_zone_role is true and create_network_resources is false."
    }
  }
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                       = var.cluster_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  dns_prefix_private_cluster = "${var.cluster_name}-dns"
  kubernetes_version         = var.kubernetes_version

  private_cluster_enabled             = var.private_cluster_enabled
  private_cluster_public_fqdn_enabled = var.private_cluster_public_fqdn_enabled
  private_dns_zone_id                 = local.effective_private_dns_zone_id

  sku_tier = var.sku_tier

  default_node_pool {
    name                 = var.system_node_pool.name
    node_count           = var.system_node_pool.auto_scaling_enabled ? null : var.system_node_pool.node_count
    vm_size              = var.system_node_pool.vm_size
    vnet_subnet_id       = var.system_node_pool.subnet_id
    type                 = "VirtualMachineScaleSets"
    min_count            = var.system_node_pool.auto_scaling_enabled ? var.system_node_pool.min_count : null
    max_count            = var.system_node_pool.auto_scaling_enabled ? var.system_node_pool.max_count : null
    zones                = var.system_node_pool.availability_zones
    auto_scaling_enabled = var.system_node_pool.auto_scaling_enabled

    only_critical_addons_enabled = var.system_node_pool.only_critical_addons_enabled

    os_disk_type    = var.system_node_pool.os_disk_type
    os_disk_size_gb = var.system_node_pool.os_disk_size_gb

    ultra_ssd_enabled = var.system_node_pool.ultra_ssd_enabled

    node_labels = var.system_node_pool.node_labels

    tags = var.tags
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  network_profile {
    network_plugin      = var.network_profile.network_plugin
    network_plugin_mode = var.network_profile.network_plugin_mode
    network_policy      = var.network_profile.network_policy
    network_data_plane  = var.network_profile.network_data_plane
    dns_service_ip      = var.network_profile.dns_service_ip
    service_cidr        = var.network_profile.service_cidrs == null ? var.network_profile.service_cidr : null
    service_cidrs       = var.network_profile.service_cidrs
    pod_cidr            = var.network_profile.pod_cidrs == null ? var.network_profile.pod_cidr : null
    pod_cidrs           = var.network_profile.pod_cidrs
    load_balancer_sku   = "standard"
    outbound_type       = var.network_profile.outbound_type

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
    for_each = var.enable_monitoring ? [local.effective_log_analytics_workspace_id] : []
    content {
      log_analytics_workspace_id = oms_agent.value
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

  automatic_upgrade_channel = var.automatic_upgrade_channel

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

  lifecycle {
    precondition {
      condition     = !var.enable_monitoring || local.effective_log_analytics_workspace_id != null
      error_message = "log_analytics_workspace_id is required when enable_monitoring is true and create_monitoring_resources is false."
    }
  }

  depends_on = [
    azurerm_role_assignment.aks_network_contributor,
    azurerm_role_assignment.aks_private_dns_zone_contributor
  ]
}

locals {
  # Pre-compute normalized values for each node pool
  node_pool_configs = {
    for k, v in var.node_pools : k => {
      is_spot         = lower(v.priority) == "spot"
      priority        = lower(v.priority) == "spot" ? "Spot" : "Regular"
      eviction_policy = lower(v.priority) == "spot" ? title(lower(v.eviction_policy)) : null
      spot_max_price  = lower(v.priority) == "spot" ? v.spot_max_price : null
    }
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "additional" {
  for_each = var.node_pools

  name                  = each.value.name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = each.value.vm_size
  node_count            = each.value.auto_scaling_enabled ? null : each.value.node_count
  vnet_subnet_id        = each.value.subnet_id

  mode = each.value.mode

  min_count            = each.value.auto_scaling_enabled ? each.value.min_count : null
  max_count            = each.value.auto_scaling_enabled ? each.value.max_count : null
  auto_scaling_enabled = each.value.auto_scaling_enabled
  zones                = each.value.availability_zones

  os_disk_type    = each.value.os_disk_type
  os_disk_size_gb = each.value.os_disk_size_gb

  ultra_ssd_enabled       = each.value.ultra_ssd_enabled
  host_encryption_enabled = each.value.enable_host_encryption

  node_labels = each.value.node_labels

  node_taints = [
    for taint in coalesce(each.value.node_taints, []) : "${taint.key}=${taint.value}:${taint.effect}"
  ]

  # Use pre-computed normalized values from locals
  priority        = local.node_pool_configs[each.key].priority
  eviction_policy = local.node_pool_configs[each.key].eviction_policy
  spot_max_price  = local.node_pool_configs[each.key].spot_max_price

  tags = merge(var.tags, each.value.tags)
}
