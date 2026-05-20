variable "tenant_id" {
  description = "Optional tenant ID override for Azure RBAC configuration in plan-only tests"
  type        = string
  default     = null
}

variable "location" {
  description = "Azure region for the fixture"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Resource group name for the fixture"
  type        = string
  default     = "rg-aks-module-test"
}

variable "cluster_name" {
  description = "AKS cluster name for the fixture"
  type        = string
  default     = "aks-module-test"
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version"
  type        = string
  default     = "1.35"
}

variable "sku_tier" {
  description = "AKS SKU tier"
  type        = string
  default     = "Standard"
}

variable "private_cluster_enabled" {
  description = "Whether to configure a private AKS API endpoint"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Whether to attach the OMS agent to Log Analytics"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_id" {
  description = "Existing Log Analytics workspace ID for plan-only tests"
  type        = string
  default     = null
}

variable "automatic_upgrade_channel" {
  description = "AKS automatic upgrade channel"
  type        = string
  default     = "patch"
}

variable "network_policy" {
  description = "AKS network policy provider"
  type        = string
  default     = "cilium"
}

variable "network_data_plane" {
  description = "AKS network data plane"
  type        = string
  default     = "cilium"
}

variable "node_pool_priority" {
  description = "Additional node pool priority"
  type        = string
  default     = "Spot"
}

variable "node_pool_eviction_policy" {
  description = "Additional node pool eviction policy"
  type        = string
  default     = "Delete"
}

variable "node_pool_spot_max_price" {
  description = "Additional node pool spot max price"
  type        = number
  default     = -1
}

variable "include_user_pool" {
  description = "Whether to include the Spark user node pool"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Fixture tags"
  type        = map(string)
  default = {
    Environment = "test"
    Purpose     = "terratest"
    Temporary   = "true"
  }
}
