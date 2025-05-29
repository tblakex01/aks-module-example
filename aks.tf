resource "azurerm_kubernetes_cluster" "aks" {
  name                       = var.cluster_name
  location                   = azurerm_resource_group.aks.location
  resource_group_name        = azurerm_resource_group.aks.name
  dns_prefix_private_cluster = "${var.cluster_name}-dns"
  kubernetes_version         = var.kubernetes_version

  private_cluster_enabled             = true
  private_cluster_public_fqdn_enabled = false

  default_node_pool {
    name                = "system"
    node_count          = var.node_count
    vm_size             = local.system_vm_size
    vnet_subnet_id      = azurerm_subnet.system.id
    type                = "VirtualMachineScaleSets"
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 5

    only_critical_addons_enabled = true
    enable_node_public_ip        = false

    os_disk_type    = "Managed"
    os_disk_size_gb = 128

    ultra_ssd_enabled = false

    node_labels = {
      "nodepool-type"                         = "system"
      "environment"                           = "production"
      "nodepoolos"                            = "linux"
      "kubernetes.azure.com/scalesetpriority" = "regular"
    }

    tags = var.tags
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    dns_service_ip    = "10.250.0.10"
    service_cidr      = "10.250.0.0/16"
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"

    load_balancer_profile {
      managed_outbound_ip_count = 2
      outbound_ports_allocated  = 8000
      idle_timeout_in_minutes   = 30
    }
  }

  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.aks.id
  }

  azure_policy_enabled = true

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  workload_identity_enabled = true
  oidc_issuer_enabled       = true

  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [2, 6]
    }
  }

  automatic_channel_upgrade = "patch"

  tags = var.tags

  depends_on = [
    azurerm_subnet.system,
    azurerm_subnet.spark
  ]
}

resource "azurerm_kubernetes_cluster_node_pool" "spark" {
  name                  = "spark"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = local.spark_vm_size
  node_count            = var.node_count
  vnet_subnet_id        = azurerm_subnet.spark.id

  mode = "User"

  enable_auto_scaling = true
  min_count           = 1
  max_count           = 10

  os_disk_type    = "Managed"
  os_disk_size_gb = 256

  ultra_ssd_enabled = false

  enable_host_encryption = false

  node_labels = {
    "nodepool-type" = "spark"
    "environment"   = "production"
    "workload-type" = "apache-spark"
    "compute-type"  = "memory-optimized"
  }

  node_taints = [
    "workload=spark:NoSchedule"
  ]

  tags = merge(var.tags, {
    "NodePool" = "Spark"
  })
}