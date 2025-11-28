# Copilot Instructions

This file provides guidance to GitHub Copilot coding agent when working with code in this repository.

## Repository Overview

This repository contains Terraform configuration for deploying an Azure Kubernetes Service (AKS) cluster optimized for Apache Spark workloads. The infrastructure includes production-grade security, monitoring, and performance optimizations.

## Project Structure

```
├── modules/aks/            # Reusable AKS Terraform module
│   ├── main.tf             # Main AKS cluster configuration
│   ├── network.tf          # Virtual network and subnets
│   ├── security.tf         # NSGs and Key Vault setup
│   ├── monitoring.tf       # Log Analytics and monitoring
│   ├── variables.tf        # Module input variables
│   └── outputs.tf          # Module output values
├── envs/                   # Environment-specific configurations
│   ├── dev/                # Development environment
│   ├── qa/                 # QA environment
│   ├── staging/            # Staging environment
│   └── prod/               # Production environment
├── examples/               # Example configurations
│   ├── basic/              # Basic usage example
│   └── spark-cluster/      # Spark-optimized cluster example
├── test/                   # Go-based tests using Terratest
│   ├── unit/               # Unit tests (no Azure resources required)
│   ├── integration/        # Integration tests (deploys real resources)
│   └── fixtures/           # Test fixtures and helper data
└── .github/workflows/      # CI/CD workflows
```

## Build and Test Instructions

### Terraform Workflow

```bash
# Navigate to an environment directory (e.g., dev, prod)
cd envs/dev

# Initialize Terraform (required after cloning or adding providers)
terraform init

# Format Terraform files (REQUIRED before committing)
terraform fmt -recursive

# Validate configuration syntax
terraform validate

# Plan infrastructure changes
terraform plan

# Apply infrastructure changes
terraform apply
```

For working with the module directly:
```bash
cd modules/aks
terraform init -backend=false
terraform validate
```

### Go Tests

```bash
# Navigate to test directory
cd test

# Run unit tests (no Azure resources needed)
go test -v -timeout 30m ./unit/...

# Run integration tests (requires Azure credentials, deploys real resources)
RUN_INTEGRATION_TESTS=true go test -v -timeout 60m ./integration/...

# Format Go code
go fmt ./...
```

## Formatting Requirements

- **Terraform files (`*.tf`)**: Run `terraform fmt -recursive` before committing
- **Go files (`*.go`)**: Run `go fmt ./...` before committing

## Linting Requirements

- After `terraform init`, run `terraform validate` for Terraform changes
- Execute `terraform plan` to ensure the configuration produces a valid plan
- For Go code, run `go vet ./...` when making changes to test files

## Code Style Guidelines

### Terraform

- Use consistent naming: `resource_type.resource_name` format
- Group related resources in the same file
- Use variables for configurable values
- Include descriptions for all variables and outputs
- Follow HashiCorp's Terraform style conventions

### Go Tests

- Use descriptive test names that explain the scenario
- Use Terratest helper functions for Azure resource validation
- Clean up resources after tests using `defer` statements
- Use table-driven tests where appropriate

## Key Design Decisions

- **Private AKS cluster**: No public endpoint for enhanced security
- **Node pool flexibility**: Configurable VM sizes (e.g., Standard_D8s_v3 for system, Standard_E8s_v5 for memory-intensive Spark workloads)
- **Node taints**: Spark nodes can be configured with `workload=spark:NoSchedule` taint
- **Autoscaling**: Configurable min/max nodes for each pool
- **Network isolation**: Separate subnets for system and Spark workloads
- **Workload identity**: Enabled for pod-level Azure authentication
- **Spot instances**: Supported for cost optimization on interruptible workloads

## Important Variables

Variables are defined in environment-specific configurations (`envs/{env}/variables.tf`):

| Variable | Description | Example Default (prod) |
|----------|-------------|------------------------|
| `location` | Azure region | `East US` |
| `cluster_name` | AKS cluster name | `aks-spark-cluster` |
| `kubernetes_version` | K8s version | `1.31.8` |
| `enable_hub_peering` | Hub VNet peering for ExpressRoute | `false` |
| `sku_tier` | Cluster SKU tier (Free/Standard) | `Standard` |

## Task Guidelines

When working on tasks in this repository:

1. **Incremental changes**: Make small, focused changes that are easy to review
2. **Validate changes**: Always run `terraform validate` and `terraform plan` for Terraform changes
3. **Run tests**: Execute relevant unit tests before submitting changes
4. **Format code**: Ensure all code is properly formatted before committing
5. **Documentation**: Update relevant documentation when making significant changes

## What Copilot Does Well Here

- Bug fixes in Terraform configurations
- Adding new variables or outputs
- Updating Terraform resource configurations
- Writing or updating Go tests
- Documentation improvements
- Code refactoring and cleanup

## Security Considerations

- Never commit secrets or credentials to the repository
- Use Azure Key Vault for secret management
- Follow the principle of least privilege for RBAC
- Ensure NSG rules are restrictive
- Validate security configurations with `terraform plan`
