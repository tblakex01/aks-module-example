variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-aks-spark-prod"
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "aks-spark-cluster"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28.5"
}

variable "node_count" {
  description = "Number of nodes per pool"
  type        = number
  default     = 3
}

variable "hub_resource_group_name" {
  description = "Name of the hub resource group containing ExpressRoute Gateway"
  type        = string
  default     = "rg-network-hub" # Update this with your actual hub RG name
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