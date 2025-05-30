# Staging Environment Configuration

# Basic Configuration
location            = "East US"
resource_group_name = "rg-aks-spark-staging"
cluster_name        = "aks-spark-staging"
kubernetes_version  = "1.31.8"
node_count          = 2
sku_tier            = "Standard" # Staging uses Standard for reliability testing

# ExpressRoute Configuration
enable_hub_peering      = false # Can be enabled for staging tests
hub_resource_group_name = ""

# Tags
tags = {
  Environment = "Staging"
  Workload    = "ApacheSpark"
  ManagedBy   = "Terraform"
  Purpose     = "Pre-production Testing"
  Owner       = "QA Team"
}
EOF < /dev/null