variable "location" {
  description = "Azure region for integration resources"
  type        = string
  default     = "East US"
}

variable "resource_group_name" {
  description = "Unique resource group name for the test run"
  type        = string
}

variable "cluster_name" {
  description = "Unique AKS cluster name for the test run"
  type        = string
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version"
  type        = string
  default     = "1.35"
}

variable "tags" {
  description = "Tags applied to all test resources"
  type        = map(string)
}
