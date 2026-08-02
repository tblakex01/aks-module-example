# AKS Module

This module creates a production-ready Azure Kubernetes Service (AKS) cluster with configurable node pools, networking, monitoring, and security features.

## Features

- **Private AKS cluster** with no public endpoint by default
- **Multiple node pools** support with auto-scaling (including Spot instances)
- **Azure AD RBAC** integration
- **Workload identity** and OIDC issuer support
- **Key Vault secrets provider** integration
- **Container Insights** monitoring
- **Flexible networking** configuration
- **Maintenance windows** support
- **Azure Policy** integration

## Usage

### Basic Example

```hcl
module "aks" {
  source = "./modules/aks"

  cluster_name                    = "my-aks-cluster"
  location                        = "East US"
  resource_group_name             = "rg-aks-prod"
  kubernetes_version              = "1.35"
  network_contributor_scope_id    = azurerm_virtual_network.main.id
  assign_network_contributor_role = true
  
  system_node_pool = {
    name                         = "system"
    vm_size                      = "Standard_D4s_v3"
    node_count                   = 3
    subnet_id                    = azurerm_subnet.system.id
    auto_scaling_enabled         = true
    min_count                    = 1
    max_count                    = 5
    availability_zones           = ["1", "2", "3"]
    only_critical_addons_enabled = true
    os_disk_type                 = "Ephemeral"
    os_disk_size_gb              = 128
    ultra_ssd_enabled            = false
    enable_host_encryption       = true
    max_pods                     = 50
    node_labels = {
      "nodepool-type" = "system"
    }
  }
  
  network_profile = {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    dns_service_ip      = "172.16.0.10"
    service_cidr        = "172.16.0.0/16"
    outbound_type       = "loadBalancer"
  }
  
  azure_ad_rbac = {
    managed            = true
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }
  create_monitoring_resources = true
  
  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}
```

### Advanced Example with Multiple Node Pools

```hcl
module "aks" {
  source = "./modules/aks"

  cluster_name                    = "aks-spark-cluster"
  location                        = "East US"
  resource_group_name             = azurerm_resource_group.main.name
  kubernetes_version              = "1.35"
  sku_tier                        = "Standard"
  private_dns_zone_id             = azurerm_private_dns_zone.aks.id
  network_contributor_scope_id    = azurerm_virtual_network.main.id
  assign_private_dns_zone_role    = true
  assign_network_contributor_role = true
  
  # System node pool for Kubernetes system components
  system_node_pool = {
    name                         = "system"
    vm_size                      = "Standard_D8s_v3"
    node_count                   = 3
    subnet_id                    = azurerm_subnet.system.id
    auto_scaling_enabled         = true
    min_count                    = 1
    max_count                    = 5
    availability_zones           = ["1", "2", "3"]
    only_critical_addons_enabled = true
    os_disk_type                 = "Ephemeral"
    os_disk_size_gb              = 128
    ultra_ssd_enabled            = false
    enable_host_encryption       = true
    max_pods                     = 50
    node_labels = {
      "nodepool-type" = "system"
      "environment"   = "production"
    }
  }
  
  # Additional node pools for workloads
  node_pools = {
    spark = {
      name                   = "spark"
      vm_size                = "Standard_E8s_v5"
      node_count             = 3
      subnet_id              = azurerm_subnet.spark.id
      mode                   = "User"
      auto_scaling_enabled   = true
      min_count              = 4
      max_count              = 10
      availability_zones     = ["1", "2", "3"]
      os_disk_type           = "Ephemeral"
      os_disk_size_gb        = 256
      ultra_ssd_enabled      = false
      enable_host_encryption = true
      max_pods               = 50
      node_labels = {
        "workload-type" = "apache-spark"
      }
      node_taints = [{
        key    = "workload"
        value  = "spark"
        effect = "NoSchedule"
      }]
      tags = {
        "NodePool" = "Spark"
      }
    },
    spot_spark_workers = {
      name                   = "spotspark"
      vm_size                = "Standard_E8s_v5"
      node_count             = 2 # Initial count for spot
      subnet_id              = azurerm_subnet.spark.id # Assuming same subnet
      mode                   = "User"
      auto_scaling_enabled   = true
      min_count              = 1
      max_count              = 10
      availability_zones     = ["1", "2", "3"]
      os_disk_type           = "Ephemeral"
      os_disk_size_gb        = 256
      ultra_ssd_enabled      = false
      enable_host_encryption = true
      max_pods               = 50
      node_labels = {
        "workload-type" = "apache-spark-spot"
        "priority"      = "spot"
      }
      node_taints = [{ # Taint to ensure only tolerant workloads run here
        key    = "workload"
        value  = "spark-spot"
        effect = "NoSchedule"
      }]
      tags = {
        "NodePool" = "SparkSpot"
      }
      # Spot instance configuration
      priority        = "Spot"
      eviction_policy = "Delete" # or "Deallocate"
      spot_max_price  = -1       # Use -1 for Azure market price, or set a specific max price
    }
  }
  
  # Network configuration
  network_profile = {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    dns_service_ip      = "172.16.0.10"
    service_cidr        = "172.16.0.0/16"
    outbound_type       = "loadBalancer"
    load_balancer_profile = {
      managed_outbound_ip_count = 2
      outbound_ports_allocated  = 8000
      idle_timeout_in_minutes   = 30
    }
  }
  
  # Azure AD RBAC
  azure_ad_rbac = {
    managed            = true
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }
  
  # Monitoring
  enable_monitoring          = true
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  
  # Security features
  azure_policy_enabled              = true
  enable_key_vault_secrets_provider = true
  workload_identity_enabled         = true
  oidc_issuer_enabled               = true
  
  # Maintenance window
  maintenance_window = {
    day   = "Sunday"
    hours = [2, 6]
  }
  
  automatic_upgrade_channel = "patch"
  
  tags = {
    Environment = "Production"
    Workload    = "ApacheSpark"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.15.0, < 2.0.0 |
| azurerm | ~> 4.73 |

## Providers

| Name | Version |
|------|---------|
| azurerm | ~> 4.73 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | Name of the AKS cluster | `string` | n/a | yes |
| location | Azure region for the AKS cluster | `string` | n/a | yes |
| resource_group_name | Name of the resource group | `string` | n/a | yes |
| kubernetes_version | Kubernetes version for the cluster | `string` | n/a | yes |
| system_node_pool | Configuration for the default system node pool | `object` | n/a | yes |
| network_profile | Network profile configuration for the cluster | `object` | n/a | yes |
| azure_ad_rbac | Azure AD RBAC configuration | `object` | n/a | yes |
| sku_tier | The SKU Tier that should be used for this Kubernetes Cluster | `string` | `"Standard"` | no |
| disk_encryption_set_id | Optional disk encryption set ID for customer-managed encryption of AKS disks | `string` | `null` | no |
| local_account_disabled | Disable local admin credentials so access is governed by Azure AD RBAC | `bool` | `true` | no |
| node_pools | Map of additional node pools to create. See `object` structure below. | `map(object)` | `{}` | no |
| private_cluster_enabled | Should this Kubernetes Cluster have its API server only exposed on internal IP addresses? | `bool` | `true` | no |
| enable_monitoring | Enable Azure Monitor for containers | `bool` | `true` | no |
| log_analytics_workspace_id | ID of the Log Analytics workspace for monitoring | `string` | `null` | no |
| create_monitoring_resources | Whether to create a Log Analytics workspace within the module | `bool` | `false` | no |
| azure_policy_enabled | Should Azure Policy be enabled on the cluster | `bool` | `true` | no |
| enable_key_vault_secrets_provider | Enable Key Vault Secrets Provider | `bool` | `true` | no |
| workload_identity_enabled | Enable workload identity | `bool` | `true` | no |
| oidc_issuer_enabled | Enable OIDC issuer | `bool` | `true` | no |
| key_vault_public_network_access_enabled | Allow public data-plane access to the module-managed Key Vault | `bool` | `false` | no |
| key_vault_private_endpoint_subnet_id | Subnet ID for the module-managed Key Vault private endpoint | `string` | `null` | no |
| key_vault_private_dns_zone_ids | Private DNS zone IDs to associate with the module-managed Key Vault private endpoint | `list(string)` | `[]` | no |
| maintenance_window | Maintenance window configuration | `object` | `null` | no |
| automatic_upgrade_channel | The automatic upgrade channel for the cluster | `string` | `"patch"` | no |
| network_contributor_scope_id | Network scope where the AKS control plane identity receives Network Contributor before cluster creation | `string` | `null` | no |
| assign_network_contributor_role | Assign Network Contributor on `network_contributor_scope_id` for externally managed networks | `bool` | `false` | no |
| private_dns_zone_id | Private DNS zone ID for private AKS API records | `string` | `null` | no |
| assign_private_dns_zone_role | Assign Private DNS Zone Contributor on `private_dns_zone_id` for externally managed private DNS zones | `bool` | `false` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

### `node_pools` Object Structure

Each object in the `node_pools` map can have the following attributes:

| Attribute | Description | Type | Default | Required |
|-----------|-------------|------|---------|:--------:|
| `name` | Name of the node pool | `string` | n/a | yes |
| `vm_size` | VM size for the nodes | `string` | n/a | yes |
| `node_count` | Initial number of nodes (if auto-scaling is disabled) | `number` | n/a | yes (if `auto_scaling_enabled` is `false`) |
| `subnet_id` | Subnet ID for the node pool | `string` | n/a | yes |
| `mode` | Mode of the node pool (System or User) | `string` | `"User"` | no |
| `auto_scaling_enabled` | Enable auto-scaling for the node pool | `bool` | `true` | no |
| `min_count` | Minimum number of nodes for auto-scaling | `number` | `1` | no |
| `max_count` | Maximum number of nodes for auto-scaling | `number` | `5` | no |
| `availability_zones` | List of availability zones | `list(string)` | `null` | no |
| `os_disk_type` | OS disk type (Managed or Ephemeral) | `string` | n/a | yes |
| `os_disk_size_gb` | OS disk size in GB | `number` | `128` | no |
| `ultra_ssd_enabled` | Enable Ultra SSD | `bool` | `false` | no |
| `enable_host_encryption` | Enable host-based encryption | `bool` | `true` | no |
| `max_pods` | Maximum pods per node | `number` | `50` | no |
| `node_labels` | Map of labels to apply to nodes | `map(string)` | `{}` | no |
| `node_taints` | List of taints to apply to nodes | `list(object)` | `[]` | no |
| `tags` | Tags to apply to the node pool | `map(string)` | `{}` | no |
| `priority` | Priority of the node pool (`Regular` or `Spot`) | `string` | `"Regular"` | no |
| `eviction_policy` | Eviction policy for Spot nodes (`Delete` or `Deallocate`) | `string` | `"Delete"` | no (required if `priority` is `Spot`) |
| `spot_max_price` | Maximum price for Spot instances (-1 for on-demand price) | `number` | `-1` | no (used if `priority` is `Spot`) |


## Outputs

| Name | Description |
|------|-------------|
| cluster_id | The Kubernetes Cluster ID |
| cluster_name | The name of the Kubernetes cluster |
| cluster_fqdn | The FQDN of the Azure Kubernetes Managed Cluster |
| cluster_private_fqdn | The FQDN for the Kubernetes Cluster when private link has been enabled |
| kube_config | Raw Kubernetes config to be used by kubectl and other compatible tools |
| node_resource_group | The name of the Resource Group where the Kubernetes Nodes should exist |
| identity_principal_id | The Principal ID of the System Assigned Managed Service Identity |
| kubelet_identity | The Kubelet Identity information |
| oidc_issuer_url | The OIDC issuer URL that is associated with the cluster |
| key_vault_secrets_provider_identity | The User Assigned Identity used by the Key Vault Secrets Provider |
| node_pools | Information about the node pools |

## Best Practices

1. **Node Pool Design**:
   - Use dedicated system node pools with `only_critical_addons_enabled = true`
   - Create separate node pools for different workload types
   - Use node taints and labels to ensure proper pod scheduling

2. **Security**:
   - Enable private cluster for production environments
   - Use Azure AD RBAC for authentication and authorization
   - Enable workload identity for pod-level Azure resource access
   - Integrate with Key Vault for secrets management

3. **Networking**:
   - Use Azure CNI for better network performance and features
   - Configure appropriate service CIDR and DNS service IP
   - Plan subnet sizes carefully based on maximum node count

4. **Monitoring**:
   - Always enable Container Insights for production clusters
   - Configure appropriate retention periods for logs
   - Set up alerts for critical metrics

5. **Maintenance**:
   - Configure maintenance windows during low-traffic periods
   - Enable automatic channel upgrades for security patches
   - Regularly update Kubernetes version

## License

This module is licensed under the MIT License.
