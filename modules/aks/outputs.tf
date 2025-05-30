output "cluster_id" {
  description = "The Kubernetes Cluster ID"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "cluster_name" {
  description = "The name of the Kubernetes cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "cluster_fqdn" {
  description = "The FQDN of the Azure Kubernetes Managed Cluster"
  value       = azurerm_kubernetes_cluster.aks.fqdn
}

output "cluster_private_fqdn" {
  description = "The FQDN for the Kubernetes Cluster when private link has been enabled"
  value       = azurerm_kubernetes_cluster.aks.private_fqdn
}

output "cluster_portal_fqdn" {
  description = "The FQDN for the Azure Portal resources when private link has been enabled"
  value       = azurerm_kubernetes_cluster.aks.portal_fqdn
}

output "kube_config" {
  description = "Raw Kubernetes config to be used by kubectl and other compatible tools"
  value       = azurerm_kubernetes_cluster.aks.kube_config
  sensitive   = true
}

output "kube_config_raw" {
  description = "Raw Kubernetes config as a string"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "host" {
  description = "The Kubernetes cluster server host"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].host
  sensitive   = true
}

output "client_certificate" {
  description = "Base64 encoded public certificate used by clients to authenticate to the Kubernetes cluster"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate
  sensitive   = true
}

output "client_key" {
  description = "Base64 encoded private key used by clients to authenticate to the Kubernetes cluster"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].client_key
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64 encoded public CA certificate used as the root of trust for the Kubernetes cluster"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate
  sensitive   = true
}

output "node_resource_group" {
  description = "The name of the Resource Group where the Kubernetes Nodes should exist"
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
}

output "identity_principal_id" {
  description = "The Principal ID of the System Assigned Managed Service Identity"
  value       = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

output "identity_tenant_id" {
  description = "The Tenant ID of the System Assigned Managed Service Identity"
  value       = azurerm_kubernetes_cluster.aks.identity[0].tenant_id
}

output "kubelet_identity" {
  description = "The Kubelet Identity information"
  value = {
    client_id                 = azurerm_kubernetes_cluster.aks.kubelet_identity[0].client_id
    object_id                 = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
    user_assigned_identity_id = azurerm_kubernetes_cluster.aks.kubelet_identity[0].user_assigned_identity_id
  }
}

output "oidc_issuer_url" {
  description = "The OIDC issuer URL that is associated with the cluster"
  value       = azurerm_kubernetes_cluster.aks.oidc_issuer_url
}

output "key_vault_secrets_provider_identity" {
  description = "The User Assigned Identity used by the Key Vault Secrets Provider"
  value = var.enable_key_vault_secrets_provider ? {
    object_id                 = azurerm_kubernetes_cluster.aks.key_vault_secrets_provider[0].secret_identity[0].object_id
    client_id                 = azurerm_kubernetes_cluster.aks.key_vault_secrets_provider[0].secret_identity[0].client_id
    user_assigned_identity_id = azurerm_kubernetes_cluster.aks.key_vault_secrets_provider[0].secret_identity[0].user_assigned_identity_id
  } : null
}

output "node_pools" {
  description = "Information about the node pools"
  value = {
    for k, v in azurerm_kubernetes_cluster_node_pool.additional : k => {
      id         = v.id
      name       = v.name
      node_count = v.node_count
      vm_size    = v.vm_size
    }
  }
}

# Optional outputs for created resources
output "vnet_id" {
  description = "The ID of the Virtual Network (if created by module)"
  value       = var.create_network_resources ? azurerm_virtual_network.aks[0].id : null
}

output "subnet_ids" {
  description = "Map of subnet IDs (if created by module)"
  value       = var.create_network_resources ? { for k, v in azurerm_subnet.aks : k => v.id } : null
}

output "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics workspace (if created by module)"
  value       = var.create_monitoring_resources ? azurerm_log_analytics_workspace.aks[0].id : null
}

output "key_vault_id" {
  description = "The ID of the Key Vault (if created by module)"
  value       = var.create_key_vault ? azurerm_key_vault.aks[0].id : null
}

output "key_vault_uri" {
  description = "The URI of the Key Vault (if created by module)"
  value       = var.create_key_vault ? azurerm_key_vault.aks[0].vault_uri : null
}