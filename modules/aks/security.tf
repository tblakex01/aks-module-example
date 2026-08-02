# Optional security resources that can be created by the module
resource "azurerm_key_vault" "aks" {
  count                         = var.create_key_vault ? 1 : 0
  name                          = "kv-${substr(replace(var.cluster_name, "-", ""), 0, 17)}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = var.azure_ad_rbac.tenant_id
  sku_name                      = var.key_vault_sku
  soft_delete_retention_days    = var.key_vault_soft_delete_retention_days
  purge_protection_enabled      = var.key_vault_purge_protection_enabled
  public_network_access_enabled = var.key_vault_public_network_access_enabled

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  lifecycle {
    precondition {
      condition     = var.key_vault_public_network_access_enabled || var.key_vault_private_endpoint_subnet_id != null
      error_message = "key_vault_private_endpoint_subnet_id is required when creating a Key Vault with public network access disabled."
    }
  }

  tags = var.tags
}

resource "azurerm_private_endpoint" "key_vault" {
  count               = var.create_key_vault && var.key_vault_private_endpoint_subnet_id != null ? 1 : 0
  name                = "pe-${azurerm_key_vault.aks[0].name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.key_vault_private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${azurerm_key_vault.aks[0].name}"
    private_connection_resource_id = azurerm_key_vault.aks[0].id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = length(var.key_vault_private_dns_zone_ids) > 0 ? [var.key_vault_private_dns_zone_ids] : []
    content {
      name                 = "default"
      private_dns_zone_ids = private_dns_zone_group.value
    }
  }
}

# Key Vault access policy for AKS cluster
resource "azurerm_key_vault_access_policy" "aks" {
  count        = var.create_key_vault && var.enable_key_vault_secrets_provider ? 1 : 0
  key_vault_id = azurerm_key_vault.aks[0].id
  tenant_id    = var.azure_ad_rbac.tenant_id
  object_id    = azurerm_kubernetes_cluster.aks.key_vault_secrets_provider[0].secret_identity[0].object_id

  secret_permissions = [
    "Get", "List"
  ]
}

resource "azurerm_role_assignment" "aks_monitoring_metrics_publisher" {
  count                            = var.enable_monitoring ? 1 : 0
  scope                            = azurerm_kubernetes_cluster.aks.id
  role_definition_name             = "Monitoring Metrics Publisher"
  principal_id                     = azurerm_kubernetes_cluster.aks.oms_agent[0].oms_agent_identity[0].object_id
  skip_service_principal_aad_check = true
}

# Variables for external integrations
variable "acr_id" {
  description = "Azure Container Registry resource ID for pull permissions"
  type        = string
  default     = null
}

# ACR pull permission
resource "azurerm_role_assignment" "aks_acr_pull" {
  count                            = var.acr_id != null ? 1 : 0
  scope                            = var.acr_id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}
