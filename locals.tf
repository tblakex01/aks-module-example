locals {
  vnet_name          = "vnetaks123"
  vnet_address_space = ["10.248.0.0/16"]

  # VM sizes optimized for Apache Spark
  system_vm_size = "Standard_D8s_v3" # 8 vCPU, 32 GB RAM - for system pods
  spark_vm_size  = "Standard_E8s_v5" # 8 vCPU, 64 GB RAM - memory optimized for Spark

  subnets = {
    system = {
      name             = "subnet-aks-system"
      address_prefixes = ["10.248.0.0/24"] # /24 = 256 IPs (251 usable)
    }
    spark = {
      name             = "subnet-aks-spark"
      address_prefixes = ["10.248.1.0/25"] # /25 = 128 IPs (123 usable) - INCREASED from /28
    }
  }
}