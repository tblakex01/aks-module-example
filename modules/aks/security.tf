# Optional security resources that can be created by the module
resource "azurerm_key_vault" "aks" {
  count                      = var.create_key_vault ? 1 : 0
  name                       = "kv-${substr(replace(var.cluster_name, "-", ""), 0, 17)}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = var.azure_ad_rbac.tenant_id
  sku_name                   = var.key_vault_sku
  soft_delete_retention_days = var.key_vault_soft_delete_retention_days
  purge_protection_enabled   = var.key_vault_purge_protection_enabled

  tags = var.tags
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

# RBAC assignments
resource "azurerm_role_assignment" "aks_network_contributor" {
  count                = var.create_network_resources ? 1 : 0
  scope                = azurerm_virtual_network.aks[0].id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

resource "azurerm_role_assignment" "aks_monitoring_metrics_publisher" {
  count                = var.enable_monitoring ? 1 : 0
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_kubernetes_cluster.aks.oms_agent[0].oms_agent_identity[0].object_id
}

# Variables for external integrations
variable "acr_id" {
  description = "Azure Container Registry resource ID for pull permissions"
  type        = string
  default     = null
}

# ACR pull permission
resource "azurerm_role_assignment" "aks_acr_pull" {
  count                = var.acr_id != null ? 1 : 0
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}