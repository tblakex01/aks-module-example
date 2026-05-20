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
  description = "Kubernetes minor version for the cluster. Use a supported GA AKS version such as 1.35."
  type        = string
  default     = "1.35"
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

variable "disk_encryption_set_id" {
  description = "Optional disk encryption set ID for customer-managed encryption of AKS disks."
  type        = string
  default     = null
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

variable "local_account_disabled" {
  description = "Disable local admin credentials so access is governed by Azure AD RBAC."
  type        = bool
  default     = true
}

variable "system_node_pool" {
  description = "Configuration for the default system node pool"
  type = object({
    name                         = string
    vm_size                      = string
    node_count                   = number
    subnet_id                    = string
    auto_scaling_enabled         = bool
    min_count                    = number
    max_count                    = number
    availability_zones           = list(string)
    only_critical_addons_enabled = bool
    os_disk_type                 = string
    os_disk_size_gb              = number
    ultra_ssd_enabled            = bool
    enable_host_encryption       = optional(bool, true)
    max_pods                     = optional(number, 50)
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
    auto_scaling_enabled   = bool
    min_count              = number
    max_count              = number
    availability_zones     = list(string)
    os_disk_type           = string
    os_disk_size_gb        = number
    ultra_ssd_enabled      = bool
    enable_host_encryption = optional(bool, true)
    max_pods               = optional(number, 50)
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
    spot_max_price  = optional(number, -1)        # Max price for Spot instances (must be -1 or >= 0), -1 uses market price
  }))
  default = {}

  validation {
    condition = length([
      for k, v in var.node_pools : k
      if !contains(["regular", "spot"], lower(v.priority))
    ]) == 0
    error_message = "Invalid priority values found. ${join(", ", [for k, v in var.node_pools : "Node pool '${k}' has invalid priority '${v.priority}'" if !contains(["regular", "spot"], lower(v.priority))])}. Priority must be either 'Regular' or 'Spot' (case-insensitive)."
  }

  validation {
    condition = length([
      for k, v in var.node_pools : k
      if lower(v.priority) == "spot" && !contains(["delete", "deallocate"], lower(v.eviction_policy))
    ]) == 0
    error_message = "Invalid eviction_policy values found. ${join(", ", [for k, v in var.node_pools : "Node pool '${k}' has invalid eviction_policy '${v.eviction_policy}'" if lower(v.priority) == "spot" && !contains(["delete", "deallocate"], lower(v.eviction_policy))])}. When priority is 'Spot', eviction_policy must be either 'Delete' or 'Deallocate' (case-insensitive)."
  }

  validation {
    condition = length([
      for k, v in var.node_pools : k
      if !(v.spot_max_price == -1 || v.spot_max_price >= 0)
    ]) == 0
    error_message = "Invalid spot_max_price values found. ${join(", ", [for k, v in var.node_pools : "Node pool '${k}' has invalid spot_max_price '${v.spot_max_price}'" if !(v.spot_max_price == -1 || v.spot_max_price >= 0)])}. The spot_max_price must be either -1 (market price) or >= 0."
  }
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
    network_plugin_mode = optional(string, "overlay")
    network_data_plane  = optional(string, "cilium")
    pod_cidr            = optional(string, "10.244.0.0/16")
    pod_cidrs           = optional(list(string))
    service_cidrs       = optional(list(string))
  })

  validation {
    condition     = contains(["azure"], lower(var.network_profile.network_plugin))
    error_message = "network_profile.network_plugin must be 'azure'."
  }

  validation {
    condition     = var.network_profile.network_policy == null || contains(["azure", "calico", "cilium"], lower(var.network_profile.network_policy))
    error_message = "network_profile.network_policy must be one of 'azure', 'calico', or 'cilium'."
  }

  validation {
    condition     = var.network_profile.network_data_plane == null || contains(["azure", "cilium"], lower(var.network_profile.network_data_plane))
    error_message = "network_profile.network_data_plane must be either 'azure' or 'cilium'."
  }
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

variable "automatic_upgrade_channel" {
  description = "The automatic upgrade channel for the cluster"
  type        = string
  default     = "patch"
  validation {
    condition     = contains(["none", "patch", "rapid", "stable", "node-image"], var.automatic_upgrade_channel)
    error_message = "Invalid automatic_upgrade_channel value."
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

variable "network_contributor_scope_id" {
  description = "Network scope where the AKS control plane identity receives Network Contributor before cluster creation"
  type        = string
  default     = null
}

variable "assign_network_contributor_role" {
  description = "Assign Network Contributor to the AKS control plane identity on network_contributor_scope_id. Set this when the network scope is managed outside the module."
  type        = bool
  default     = false
}

variable "private_dns_zone_id" {
  description = "Private DNS zone ID for private AKS API records. Required when using externally managed private DNS."
  type        = string
  default     = null
}

variable "assign_private_dns_zone_role" {
  description = "Assign Private DNS Zone Contributor to the AKS control plane identity on private_dns_zone_id. Set this when the private DNS zone is managed outside the module."
  type        = bool
  default     = false
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

variable "key_vault_public_network_access_enabled" {
  description = "Allow public data-plane access to the module-managed Key Vault. Keep disabled unless a documented exception exists."
  type        = bool
  default     = false
}

variable "key_vault_private_endpoint_subnet_id" {
  description = "Subnet ID for the module-managed Key Vault private endpoint. Required when create_key_vault is true and public access is disabled."
  type        = string
  default     = null
}

variable "key_vault_private_dns_zone_ids" {
  description = "Private DNS zone IDs to associate with the module-managed Key Vault private endpoint."
  type        = list(string)
  default     = []
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
