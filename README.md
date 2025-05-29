# Azure Kubernetes Service (AKS) Cluster for Apache Spark

This repository contains Terraform configuration for deploying a production-grade Azure Kubernetes Service (AKS) cluster optimized for Apache Spark workloads. The infrastructure is designed with enterprise-level security, monitoring, and performance optimizations.

## 🚀 Features

### Core Infrastructure
- **Private AKS Cluster**: Fully private Kubernetes cluster with no public endpoint
- **Multi-AZ Deployment**: High availability across 3 availability zones
- **Auto-scaling**: Dynamic scaling for both system and Spark workloads
- **Workload Identity**: Pod-level Azure resource authentication
- **Azure AD RBAC**: Fully managed role-based access control

### Node Pools
- **System Pool**: Dedicated for Kubernetes system components (1-5 nodes)
- **Spark Pool**: Isolated pool for Apache Spark workloads (4-10 nodes)
- **Node Taints**: Ensures Spark workloads run on dedicated nodes

### Security & Networking
- **Hub-Spoke Architecture**: Enterprise network topology with ExpressRoute support
- **Network Security Groups**: Restrictive firewall rules
- **Key Vault Integration**: Secure secret management with CSI driver
- **Private DNS Zone**: Internal cluster name resolution

### Monitoring & Observability
- **Log Analytics Workspace**: Centralized logging with 30-day retention
- **Container Insights**: Full AKS monitoring solution
- **Azure Policy**: Governance and compliance enforcement

## 📋 Prerequisites

- Azure subscription with appropriate permissions
- Terraform >= 1.0
- Azure CLI (for authentication)
- [Optional] Existing hub VNet for ExpressRoute connectivity

## 🛠️ Quick Start

### 1. Clone the Repository
```bash
git clone <repository-url>
cd aks-cluster
```

### 2. Initialize Terraform
```bash
terraform init
```

### 3. Configure Variables
Create a `terraform.tfvars` file:
```hcl
location         = "East US"
cluster_name     = "aks-spark-prod"
environment      = "production"
enable_expressroute = true  # If you have ExpressRoute
```

### 4. Review the Plan
```bash
terraform plan
```

### 5. Deploy the Infrastructure
```bash
terraform apply
```

## 📁 Project Structure

```
aks-cluster/
├── aks.tf              # Main AKS cluster configuration
├── bastion.tf.example  # Example bastion host configuration
├── data.tf             # Data sources for existing resources
├── locals.tf           # Local values and computed configurations
├── monitoring.tf       # Log Analytics and monitoring setup
├── network.tf          # Virtual network and subnets
├── outputs.tf          # Output values for integration
├── peering.tf          # VNet peering configuration
├── providers.tf        # Azure provider configuration
├── security.tf         # NSGs and Key Vault setup
├── variables.tf        # Input variables
└── versions.tf         # Terraform and provider versions
```

## 🔧 Configuration

### Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `location` | Azure region for resources | `East US` |
| `cluster_name` | Name of the AKS cluster | `aks-spark-cluster` |
| `environment` | Environment name (dev/prod) | `prod` |
| `kubernetes_version` | Kubernetes version | `1.31.8` |
| `enable_expressroute` | Enable ExpressRoute connectivity | `false` |
| `spark_node_count` | Initial Spark node pool size | `3` |
| `system_node_count` | Initial system node pool size | `3` |

### Network Configuration

The cluster uses the following network architecture:
- **VNet CIDR**: 10.248.27.0/24
- **System Subnet**: 10.248.27.0/26
- **Spark Subnet**: 10.248.27.64/26
- **Private Endpoints**: 10.248.27.128/27
- **Service CIDR**: 10.250.0.0/16

### Spark Optimization

The Spark node pool is optimized with:
- **Dedicated Nodes**: Tainted with `workload=spark:NoSchedule`
- **VM Size**: Standard_D8s_v3 (8 vCPU, 32 GB RAM)
- **OS Disk**: 256 GB for data processing
- **Auto-scaling**: 4-10 nodes based on workload

## 🔐 Security

### Network Security
- Private cluster with no public endpoint
- Restrictive NSG rules allowing only necessary traffic
- Integration with ExpressRoute for secure on-premises connectivity

### Identity & Access
- Azure AD RBAC for Kubernetes access control
- Workload Identity for pod-level authentication
- System-assigned managed identity for cluster operations

### Secret Management
- Azure Key Vault integration with CSI driver
- Automatic secret rotation every 2 minutes
- Soft delete and purge protection enabled

## 📊 Monitoring

The cluster includes comprehensive monitoring:
- **Log Analytics Workspace**: Centralized logging
- **Container Insights**: Performance metrics and diagnostics
- **Azure Policy**: Compliance and governance monitoring

## 💰 Cost Estimation

### Monthly Cost Breakdown (East US Region)

| Resource | Configuration | Est. Monthly Cost |
|----------|--------------|-------------------|
| **AKS Cluster Management** | Standard SKU | ~$73 |
| **System Node Pool** | 3 × D8s_v3 (min 1, max 5) | ~$840 - $1,400 |
| **Spark Node Pool** | 3 × D8s_v3 (min 4, max 10) | ~$1,120 - $2,800 |
| **Managed Disks** | | |
| - System OS Disks | 3 × 128 GB Standard SSD | ~$60 |
| - Spark OS Disks | 3 × 256 GB Standard SSD | ~$120 |
| **Load Balancer** | Standard + 2 Public IPs | ~$25 + $7.50 |
| **Log Analytics** | ~50 GB/month ingestion | ~$125 |
| **Key Vault** | Standard + operations | ~$5 |
| **Private DNS Zone** | 1 zone + queries | ~$0.50 |
| **Total (Minimum)** | With min nodes | **~$2,376/month** |
| **Total (Maximum)** | With max autoscaling | **~$4,556/month** |

### Cost Optimization Tips

1. **Reserved Instances**: Save up to 72% with 1 or 3-year reservations
2. **Spot Instances**: Use for non-critical Spark workloads (up to 90% savings)
3. **Auto-scaling**: Configure based on actual workload patterns
4. **Right-sizing**: Monitor usage and adjust VM sizes accordingly
5. **Log Retention**: Reduce retention period if 30 days is excessive

### Additional Costs to Consider

- **Data Transfer**: Egress charges for data leaving Azure region
- **ExpressRoute**: If enabled, circuit and gateway costs
- **Backup Solutions**: If implementing cluster backup
- **Container Registry**: If using private container images

*Note: Prices are estimates based on Azure's pay-as-you-go pricing and may vary. Use the [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) for accurate estimates.*

## 🚦 Maintenance

### Automatic Updates
- Configured maintenance window: Sundays 2:00 AM - 6:00 AM
- Automatic security patching enabled
- Node image updates managed by Azure

### Scaling
Both node pools support auto-scaling:
- **System Pool**: 1-5 nodes
- **Spark Pool**: 4-10 nodes

## 📤 Outputs

The configuration provides the following outputs:

| Output | Description |
|--------|-------------|
| `cluster_id` | AKS cluster resource ID |
| `cluster_name` | AKS cluster name |
| `kube_config` | Base64 encoded kubeconfig |
| `cluster_identity` | Cluster managed identity |
| `key_vault_id` | Key Vault resource ID |
| `log_analytics_workspace_id` | Log Analytics workspace ID |

## 🔗 Integration

### Connecting to the Cluster
```bash
# Get credentials
az aks get-credentials --resource-group rg-aks-spark-prod --name aks-spark-prod

# Verify connection
kubectl get nodes
```

### ExpressRoute Integration
When `enable_expressroute = true`, the cluster:
- Peers with the hub VNet
- Uses hub's ExpressRoute gateway
- Routes on-premises traffic through ExpressRoute

## 📚 Additional Resources

- [ACCESS_GUIDE.md](ACCESS_GUIDE.md) - Detailed access instructions
- [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) - Pre-deployment checklist
- [EXPRESSROUTE_SETUP.md](EXPRESSROUTE_SETUP.md) - ExpressRoute configuration guide
- [PRODUCTION_READINESS.md](PRODUCTION_READINESS.md) - Production deployment guide

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🏗️ Built With

- **Terraform** ~> 1.0
- **AzureRM Provider** ~> 3.85
- **Azure Kubernetes Service** 1.31.8

## 🙏 Acknowledgments

- Azure Kubernetes Service documentation
- Terraform AzureRM provider documentation
- Apache Spark on Kubernetes best practices