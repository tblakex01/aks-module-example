# Development Environment Configuration

# Basic Configuration
location            = "East US"
resource_group_name = "rg-aks-spark-dev"
cluster_name        = "aks-spark-dev"
kubernetes_version  = "1.35"
node_count          = 1
sku_tier            = "Standard"

# ExpressRoute Configuration
enable_hub_peering      = false # Not needed for dev
hub_resource_group_name = ""

# Tags
tags = {
  Environment = "Development"
  Workload    = "ApacheSpark"
  ManagedBy   = "Terraform"
  Purpose     = "Development and Testing"
  Owner       = "Dev Team"
}
