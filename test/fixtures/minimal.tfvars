# Minimal configuration for testing
# This configuration creates the smallest possible AKS cluster for testing

location           = "East US"
cluster_name       = "test-aks-minimal"
environment        = "test"
kubernetes_version = "1.31.8"

# Minimal node configuration
system_node_count = 1
system_min_count  = 1
system_max_count  = 2

spark_node_count = 1
spark_min_count  = 1
spark_max_count  = 2

# Disable ExpressRoute for testing
enable_expressroute = false

# Use smaller VM sizes for testing (optional - uncomment to use)
# system_vm_size = "Standard_D2s_v3"
# spark_vm_size  = "Standard_D2s_v3"

# Shorter retention for testing
log_analytics_retention_in_days = 7

# Tags for test resources
tags = {
  Environment = "test"
  Purpose     = "terratest"
  Temporary   = "true"
}