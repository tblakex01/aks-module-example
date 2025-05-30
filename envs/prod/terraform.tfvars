# Production Environment Configuration

# Basic Configuration
location            = "East US"
resource_group_name = "rg-aks-spark-prod"
cluster_name        = "aks-spark-cluster"
kubernetes_version  = "1.31.8"
node_count          = 3
sku_tier            = "Standard" # Production SLA

# ExpressRoute Configuration
enable_hub_peering      = false # Set to true when hub is available
hub_resource_group_name = ""    # Set this to enable hub peering

# Tags
tags = {
  Environment = "Production"
  Workload    = "ApacheSpark"
  ManagedBy   = "Terraform"
  CostCenter  = "DataEngineering"
  Owner       = "Platform Team"
}