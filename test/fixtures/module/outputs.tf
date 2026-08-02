output "private_dns_zone_id" {
  value = module.aks.private_dns_zone_id
}

output "identity_id" {
  value = module.aks.identity_id
}

output "log_analytics_workspace_id" {
  value = module.aks.log_analytics_workspace_id
}

output "node_pools" {
  value = module.aks.node_pools
}
