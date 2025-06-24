variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "location" {
  description = "Azure region for the AKS cluster"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the cluster"
  type        = string
}

variable "sku_tier" {
  description = "The SKU Tier that should be used for this Kubernetes Cluster"
  type        = string
  default     = "Standard"
  validation {
    condition     = contains(["Free", "Standard"], var.sku_tier)
    error_message = "SKU tier must be either Free or Standard."
  }
}

variable "private_cluster_enabled" {
  description = "Should this Kubernetes Cluster have its API server only exposed on internal IP addresses?"
  type        = bool
  default     = true
}

variable "private_cluster_public_fqdn_enabled" {
  description = "Specifies whether a Public FQDN for this Private Cluster should be added"
  type        = bool
  default     = false
}

variable "system_node_pool" {
  description = "Configuration for the default system node pool"
  type = object({
    name                         = string
    vm_size                      = string
    node_count                   = number
    subnet_id                    = string
    enable_auto_scaling          = bool
    min_count                    = number
    max_count                    = number
    availability_zones           = list(string)
    only_critical_addons_enabled = bool
    os_disk_type                 = string
    os_disk_size_gb              = number
    ultra_ssd_enabled            = bool
    node_labels                  = map(string)
  })
}

variable "node_pools" {
  description = "Map of additional node pools to create"
  type = map(object({
    name                   = string
    vm_size                = string
    node_count             = number
    subnet_id              = string
    mode                   = string
    enable_auto_scaling    = bool
    min_count              = number
    max_count              = number
    availability_zones     = list(string)
    os_disk_type           = string
    os_disk_size_gb        = number
    ultra_ssd_enabled      = bool
    enable_host_encryption = bool
    node_labels            = map(string)
    node_taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
    tags = map(string)
    # Spot instance configuration
    priority        = optional(string, "Regular") # Valid values: "Regular" or "Spot" (case-insensitive)
    eviction_policy = optional(string, "Delete")  # Valid values: "Delete" or "Deallocate" (case-insensitive, only used when priority is "Spot")
    spot_max_price  = optional(number, -1)        # Max price for Spot instances (must be >= -1), -1 uses market price
  }))
  default = {}
}

variable "network_profile" {
  description = "Network profile configuration for the cluster"
  type = object({
    network_plugin = string
    network_policy = string
    dns_service_ip = string
    service_cidr   = string
    outbound_type  = string
    load_balancer_profile = optional(object({
      managed_outbound_ip_count = number
      outbound_ports_allocated  = number
      idle_timeout_in_minutes   = number
    }))
  })
}

variable "azure_ad_rbac" {
  description = "Azure AD RBAC configuration"
  type = object({
    managed            = bool
    azure_rbac_enabled = bool
    tenant_id          = string
  })
}

variable "enable_monitoring" {
  description = "Enable Azure Monitor for containers"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace for monitoring"
  type        = string
  default     = null
}

variable "azure_policy_enabled" {
  description = "Should Azure Policy be enabled on the cluster"
  type        = bool
  default     = true
}

variable "enable_key_vault_secrets_provider" {
  description = "Enable Key Vault Secrets Provider"
  type        = bool
  default     = true
}

variable "key_vault_secrets_provider_config" {
  description = "Configuration for Key Vault Secrets Provider"
  type = object({
    secret_rotation_enabled  = bool
    secret_rotation_interval = string
  })
  default = {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }
}

variable "workload_identity_enabled" {
  description = "Enable workload identity"
  type        = bool
  default     = true
}

variable "oidc_issuer_enabled" {
  description = "Enable OIDC issuer"
  type        = bool
  default     = true
}

variable "maintenance_window" {
  description = "Maintenance window configuration"
  type = object({
    day   = string
    hours = list(number)
  })
  default = null
}

variable "automatic_channel_upgrade" {
  description = "The automatic upgrade channel for the cluster"
  type        = string
  default     = "patch"
  validation {
    condition     = contains(["none", "patch", "rapid", "stable", "node-image"], var.automatic_channel_upgrade)
    error_message = "Invalid automatic_channel_upgrade value."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Network-specific variables
variable "create_network_resources" {
  description = "Whether to create network resources (VNet, subnets, NSG) within the module"
  type        = bool
  default     = false
}

variable "vnet_name" {
  description = "Name of the VNet (required if create_network_resources is true)"
  type        = string
  default     = null
}

variable "vnet_address_space" {
  description = "Address space for the VNet (required if create_network_resources is true)"
  type        = list(string)
  default     = null
}

# Monitoring-specific variables
variable "create_monitoring_resources" {
  description = "Whether to create monitoring resources (Log Analytics) within the module"
  type        = bool
  default     = false
}

variable "log_analytics_retention_days" {
  description = "Retention period for Log Analytics workspace"
  type        = number
  default     = 30
}

# Security-specific variables
variable "create_key_vault" {
  description = "Whether to create a Key Vault within the module"
  type        = bool
  default     = false
}

variable "key_vault_sku" {
  description = "SKU for the Key Vault"
  type        = string
  default     = "standard"
}

variable "key_vault_soft_delete_retention_days" {
  description = "Soft delete retention days for Key Vault"
  type        = number
  default     = 90
}

variable "key_vault_purge_protection_enabled" {
  description = "Enable purge protection for Key Vault"
  type        = bool
  default     = true
}

# Network configuration variables
variable "subnet_config" {
  description = "Configuration for subnets to create"
  type = map(object({
    name             = string
    address_prefixes = list(string)
  }))
  default = {}
}

variable "additional_security_rules" {
  description = "Additional security rules to add to the NSG"
  type = list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = optional(string)
    destination_port_range     = optional(string)
    source_port_ranges         = optional(list(string))
    destination_port_ranges    = optional(list(string))
    source_address_prefix      = optional(string)
    destination_address_prefix = optional(string)
  }))
  default = []
}