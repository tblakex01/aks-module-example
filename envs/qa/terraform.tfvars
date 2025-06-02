# QA Environment Configuration

# Basic Configuration
location            = "East US"
resource_group_name = "rg-aks-spark-qa"
cluster_name        = "aks-spark-qa"
kubernetes_version  = "1.31.8"
node_count          = 3
sku_tier            = "Free" # QA uses Free tier

# ExpressRoute Configuration
enable_hub_peering      = false # Not needed for qa
hub_resource_group_name = ""

# Tags
tags = {
  Environment = "QA"
  Workload    = "ApacheSpark"
  ManagedBy   = "Terraform"
  Purpose     = "Quality Assurance and Testing"
  Owner       = "QA Team"
}