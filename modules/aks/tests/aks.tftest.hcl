mock_provider "azurerm" {
  override_during = plan
}

variables {
  cluster_name                    = "aks-module-test"
  location                        = "eastus"
  resource_group_name             = "rg-aks-module-test"
  kubernetes_version              = "1.35"
  private_dns_zone_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-aks-module-test/providers/Microsoft.Network/privateDnsZones/privatelink.eastus.azmk8s.io"
  network_contributor_scope_id    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-aks-module-test/providers/Microsoft.Network/virtualNetworks/vnet-aks-module-test"
  assign_network_contributor_role = true
  assign_private_dns_zone_role    = true
  log_analytics_workspace_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-aks-module-test/providers/Microsoft.OperationalInsights/workspaces/law-aks-module-test"

  system_node_pool = {
    name                         = "system"
    vm_size                      = "Standard_D2s_v5"
    node_count                   = 1
    subnet_id                    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-aks-module-test/providers/Microsoft.Network/virtualNetworks/vnet-aks-module-test/subnets/subnet-aks-system"
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

  node_pools = {
    spark = {
      name                   = "spark"
      vm_size                = "Standard_D2s_v5"
      node_count             = 1
      subnet_id              = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-aks-module-test/providers/Microsoft.Network/virtualNetworks/vnet-aks-module-test/subnets/subnet-aks-spark"
      mode                   = "User"
      auto_scaling_enabled   = true
      min_count              = 1
      max_count              = 5
      availability_zones     = ["1", "2", "3"]
      os_disk_type           = "Managed"
      os_disk_size_gb        = 128
      ultra_ssd_enabled      = false
      enable_host_encryption = false
      node_labels            = { workload = "spark" }
      node_taints = [{
        key    = "workload"
        value  = "spark"
        effect = "NoSchedule"
      }]
      tags            = { NodePool = "Spark" }
      priority        = "Spot"
      eviction_policy = "Delete"
      spot_max_price  = -1
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
    tenant_id          = "11111111-1111-1111-1111-111111111111"
  }

  tags = {
    Environment = "test"
    Purpose     = "terratest"
    Temporary   = "true"
  }
}

run "cilium_private_dns_monitoring_plan" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.aks.private_dns_zone_id == var.private_dns_zone_id
    error_message = "private AKS clusters must attach the caller-provided private DNS zone"
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.network_profile[0].network_policy == "cilium"
    error_message = "AKS network policy should use Cilium"
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.network_profile[0].network_data_plane == "cilium"
    error_message = "AKS network dataplane should use Cilium"
  }
}

run "optional_monitoring_and_private_cluster_disabled" {
  command = plan

  variables {
    private_cluster_enabled    = false
    enable_monitoring          = false
    log_analytics_workspace_id = null
    node_pools                 = {}
  }

  assert {
    condition     = output.private_dns_zone_id == null
    error_message = "public clusters must not configure a private DNS zone"
  }
}

run "invalid_sku_fails_fast" {
  command = plan

  variables {
    sku_tier = "Premium"
  }

  expect_failures = [
    var.sku_tier,
  ]
}

run "invalid_upgrade_channel_fails_fast" {
  command = plan

  variables {
    automatic_upgrade_channel = "preview"
  }

  expect_failures = [
    var.automatic_upgrade_channel,
  ]
}

run "invalid_network_policy_fails_fast" {
  command = plan

  variables {
    network_profile = {
      network_plugin      = "azure"
      network_plugin_mode = "overlay"
      network_policy      = "azure-npm"
      network_data_plane  = "cilium"
      dns_service_ip      = "172.16.0.10"
      service_cidr        = "172.16.0.0/16"
      pod_cidr            = "10.244.0.0/16"
      outbound_type       = "loadBalancer"
    }
  }

  expect_failures = [
    var.network_profile,
  ]
}

run "invalid_spot_priority_fails_fast" {
  command = plan

  variables {
    node_pools = {
      spark = merge(var.node_pools.spark, { priority = "Burst" })
    }
  }

  expect_failures = [
    var.node_pools,
  ]
}

run "invalid_spot_eviction_policy_fails_fast" {
  command = plan

  variables {
    node_pools = {
      spark = merge(var.node_pools.spark, { eviction_policy = "Retain" })
    }
  }

  expect_failures = [
    var.node_pools,
  ]
}

run "invalid_spot_price_fails_fast" {
  command = plan

  variables {
    node_pools = {
      spark = merge(var.node_pools.spark, { spot_max_price = -2 })
    }
  }

  expect_failures = [
    var.node_pools,
  ]
}
