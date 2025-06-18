# AKS Module

This module creates a production-ready Azure Kubernetes Service (AKS) cluster with configurable node pools, networking, monitoring, and security features.

## Features

- **Private AKS cluster** with no public endpoint by default
- **Multiple node pools** support with auto-scaling
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

  cluster_name        = "my-aks-cluster"
  location            = "East US"
  resource_group_name = "rg-aks-prod"
  kubernetes_version  = "1.28.5"
  
  system_node_pool = {
    name                         = "system"
    vm_size                      = "Standard_D4s_v3"
    node_count                   = 3
    subnet_id                    = azurerm_subnet.system.id
    enable_auto_scaling          = true
    min_count                    = 1
    max_count                    = 5
    availability_zones           = ["1", "2", "3"]
    only_critical_addons_enabled = true
    os_disk_type                 = "Managed"
    os_disk_size_gb              = 128
    ultra_ssd_enabled            = false
    node_labels                  = {
      "nodepool-type" = "system"
    }
  }
  
  network_profile = {
    network_plugin = "azure"
    network_policy = "azure"
    dns_service_ip = "10.0.0.10"
    service_cidr   = "10.0.0.0/16"
    outbound_type  = "loadBalancer"
  }
  
  azure_ad_rbac = {
    managed            = true
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }
  
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

  cluster_name        = "aks-spark-cluster"
  location            = "East US"
  resource_group_name = azurerm_resource_group.main.name
  kubernetes_version  = "1.28.5"
  sku_tier            = "Standard"
  
  # System node pool for Kubernetes system components
  system_node_pool = {
    name                         = "system"
    vm_size                      = "Standard_D8s_v3"
    node_count                   = 3
    subnet_id                    = azurerm_subnet.system.id
    enable_auto_scaling          = true
    min_count                    = 1
    max_count                    = 5
    availability_zones           = ["1", "2", "3"]
    only_critical_addons_enabled = true
    os_disk_type                 = "Managed"
    os_disk_size_gb              = 128
    ultra_ssd_enabled            = false
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
      enable_auto_scaling    = true
      min_count              = 4
      max_count              = 10
      availability_zones     = ["1", "2", "3"]
      os_disk_type           = "Managed"
      os_disk_size_gb        = 256
      ultra_ssd_enabled      = false
      enable_host_encryption = false
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
    }
  }
  
  # Network configuration
  network_profile = {
    network_plugin = "azure"
    network_policy = "azure"
    dns_service_ip = "10.0.0.10"
    service_cidr   = "10.0.0.0/16"
    outbound_type  = "loadBalancer"
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
  
  automatic_channel_upgrade = "patch"
  
  tags = {
    Environment = "Production"
    Workload    = "ApacheSpark"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| azurerm | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| azurerm | >= 3.0 |

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
| node_pools | Map of additional node pools to create | `map(object)` | `{}` | no |
| private_cluster_enabled | Should this Kubernetes Cluster have its API server only exposed on internal IP addresses? | `bool` | `true` | no |
| enable_monitoring | Enable Azure Monitor for containers | `bool` | `true` | no |
| log_analytics_workspace_id | ID of the Log Analytics workspace for monitoring | `string` | `null` | no |
| azure_policy_enabled | Should Azure Policy be enabled on the cluster | `bool` | `true` | no |
| enable_key_vault_secrets_provider | Enable Key Vault Secrets Provider | `bool` | `true` | no |
| workload_identity_enabled | Enable workload identity | `bool` | `true` | no |
| oidc_issuer_enabled | Enable OIDC issuer | `bool` | `true` | no |
| maintenance_window | Maintenance window configuration | `object` | `null` | no |
| automatic_channel_upgrade | The automatic upgrade channel for the cluster | `string` | `"patch"` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

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