output "cluster_id" {
  description = "The Kubernetes Cluster ID"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "cluster_name" {
  description = "The name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "cluster_fqdn" {
  description = "The FQDN of the Azure Kubernetes Managed Cluster"
  value       = azurerm_kubernetes_cluster.aks.fqdn
}

output "cluster_private_fqdn" {
  description = "The FQDN for the AKS cluster when private link has been enabled"
  value       = azurerm_kubernetes_cluster.aks.private_fqdn
}

output "kube_admin_config_raw" {
  description = "Raw Kubernetes config for administrative access"
  value       = azurerm_kubernetes_cluster.aks.kube_admin_config_raw
  sensitive   = true
}

output "cluster_identity" {
  description = "The managed identity of the AKS cluster"
  value = {
    type         = azurerm_kubernetes_cluster.aks.identity[0].type
    principal_id = azurerm_kubernetes_cluster.aks.identity[0].principal_id
    tenant_id    = azurerm_kubernetes_cluster.aks.identity[0].tenant_id
  }
}

output "node_resource_group" {
  description = "The name of the Resource Group where the Kubernetes Nodes reside"
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
}

output "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.aks.id
}

output "key_vault_id" {
  description = "The ID of the Key Vault"
  value       = azurerm_key_vault.aks.id
}

output "vnet_id" {
  description = "The ID of the Virtual Network"
  value       = azurerm_virtual_network.aks.id
}

output "subnet_ids" {
  description = "The IDs of the subnets"
  value = {
    system    = azurerm_subnet.system.id
    spark     = azurerm_subnet.spark.id
    endpoints = azurerm_subnet.endpoints.id
  }
}

output "peering_status" {
  description = "VNet peering status"
  value = var.enable_hub_peering ? {
    spoke_to_hub = azurerm_virtual_network_peering.spoke_to_hub[0].id
    hub_to_spoke = azurerm_virtual_network_peering.hub_to_spoke[0].id
  } : null
}

output "route_table_id" {
  description = "Route table ID for ExpressRoute traffic"
  value       = azurerm_route_table.aks_expressroute.id
}