# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains Terraform configuration for deploying an Azure Kubernetes Service (AKS) cluster optimized for Apache Spark workloads. The infrastructure is designed with production-grade security, monitoring, and performance optimizations.

## Common Commands

### Terraform Workflow
```bash
# Initialize Terraform (required after cloning or adding providers)
terraform init

# Validate configuration syntax
terraform validate

# Format Terraform files
terraform fmt -recursive

# Plan infrastructure changes
terraform plan

# Apply infrastructure changes
terraform apply

# Destroy infrastructure (use with caution)
terraform destroy
```

### Development Commands
```bash
# Preview changes with specific variables
terraform plan -var="location=West US 2" -var="cluster_name=my-aks-cluster"

# Apply with auto-approve (use carefully)
terraform apply -auto-approve

# Target specific resources
terraform apply -target=azurerm_kubernetes_cluster.aks

# Import existing resources
terraform import azurerm_resource_group.aks /subscriptions/{subscription-id}/resourceGroups/{resource-group-name}
```

## Architecture Overview

### Infrastructure Components
1. **Private AKS Cluster**: Deployed with private endpoint, no public access
2. **Node Pools**:
   - System pool: Standard_D8s_v3 VMs for Kubernetes system components
   - Spark pool: Standard_E8s_v5 memory-optimized VMs with node taints for dedicated Spark workloads
3. **Networking**: Private VNet with separate subnets for system and Spark nodes
4. **Security**: Network Security Groups, Azure AD RBAC, workload identity, Key Vault integration
5. **Monitoring**: Log Analytics workspace with Container Insights

### Key Design Decisions
- **Private cluster**: Enhanced security with no public endpoint
- **Memory-optimized VMs**: E8s_v5 instances for Spark's memory-intensive operations
- **Node taints**: Spark nodes have `workload=spark:NoSchedule` taint to ensure only Spark pods are scheduled
- **Autoscaling**: Both node pools have autoscaling enabled (system: 1-5 nodes, spark: 1-10 nodes)
- **Network isolation**: Separate subnets for system and Spark workloads
- **Workload identity**: Enabled for pod-level Azure resource authentication

### Resource Dependencies
The Terraform configuration has implicit dependencies:
1. Resource Group must be created first
2. VNet and subnets depend on Resource Group
3. AKS cluster depends on subnets
4. Node pools depend on AKS cluster
5. Key Vault access policies depend on AKS cluster identity

### Important Variables
- `location`: Azure region (default: "East US")
- `cluster_name`: AKS cluster name (default: "aks-spark-cluster")
- `kubernetes_version`: K8s version (default: "1.28.5")
- `node_count`: Initial node count per pool (default: 3)