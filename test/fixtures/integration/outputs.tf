output "resource_group_name" {
  value = azurerm_resource_group.test.name
}

output "cluster_id" {
  value = module.aks.cluster_id
}

output "cluster_name" {
  value = module.aks.cluster_name
}

output "private_dns_zone_id" {
  value = azurerm_private_dns_zone.aks.id
}

output "vnet_id" {
  value = azurerm_virtual_network.test.id
}

output "system_subnet_id" {
  value = azurerm_subnet.system.id
}

output "spark_subnet_id" {
  value = azurerm_subnet.spark.id
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.test.id
}

output "identity_id" {
  value = module.aks.identity_id
}
