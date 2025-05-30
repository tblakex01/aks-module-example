variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-aks-spark-staging"
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "aks-spark-staging"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31.8"
}

variable "node_count" {
  description = "Number of nodes per pool"
  type        = number
  default     = 3
}

variable "hub_resource_group_name" {
  description = "Name of the hub resource group containing ExpressRoute Gateway"
  type        = string
  default     = "" # Set this to enable hub peering
}

variable "enable_hub_peering" {
  description = "Enable peering with hub VNet for ExpressRoute connectivity"
  type        = bool
  default     = false # Set to true when hub is available
}

variable "sku_tier" {
  description = "The SKU Tier that should be used for this Kubernetes Cluster"
  type        = string
  default     = "Free" # Dev uses Free tier
  validation {
    condition     = contains(["Free", "Standard"], var.sku_tier)
    error_message = "SKU tier must be either Free or Standard."
  }
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "Production"
    Workload    = "ApacheSpark"
    ManagedBy   = "Terraform"
  }
}