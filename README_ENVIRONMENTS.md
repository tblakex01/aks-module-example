# Environment-Based Terraform Structure

This repository follows Terraform best practices with an environment-based folder structure, allowing for clear separation of concerns and environment-specific configurations.

## Repository Structure

```
.
├── envs/                    # Environment-specific configurations
│   ├── dev/                 # Development environment
│   ├── staging/             # Staging environment
│   └── prod/                # Production environment
├── modules/                 # Reusable Terraform modules
│   └── aks/                 # AKS cluster module
├── examples/                # Example configurations
├── test/                    # Terratest integration tests
└── docs/                    # Documentation
```

## Working with Environments

Each environment has its own directory under `envs/` containing:
- `main.tf` - Main Terraform configuration
- `variables.tf` - Variable definitions
- `outputs.tf` - Output definitions
- `terraform.tfvars` - Environment-specific variable values
- `providers.tf` - Provider configuration
- Additional environment-specific files

### Development Environment
- **Purpose**: Development and testing
- **Location**: `envs/dev/`
- **Characteristics**:
  - Free SKU tier for cost savings
  - Smaller VM sizes (D2s_v3 for system, D4s_v3 for Spark)
  - Minimal node counts (1-3 nodes)
  - Separate VNet range: 10.0.1.0/24

### QA Environment
- **Purpose**: Quality assurance and testing
- **Location**: `envs/qa/`
- **Characteristics**:
  - Standard SKU tier for testing
  - Small VM sizes (D2s_v3 for system, D4s_v3 for Spark)
  - Minimal node counts (1-3 nodes)
  - Separate VNet range: 10.0.2.0/24

### Staging Environment
- **Purpose**: Pre-production testing and validation
- **Location**: `envs/staging/`
- **Characteristics**:
  - Standard SKU tier for reliability testing
  - Medium VM sizes (D4s_v3 for system, D8s_v3 for Spark)
  - Moderate node counts (2-5 nodes)
  - Separate VNet range: 10.0.3.0/24

### Production Environment
- **Purpose**: Production workloads
- **Location**: `envs/prod/`
- **Characteristics**:
  - Standard SKU tier with SLA
  - Production VM sizes (D8s_v3 for both system and Spark)
  - Production node counts (3-10 nodes)
  - Production VNet range: 10.0.4.0/24
  - ExpressRoute connectivity ready

## Deployment Workflow

### 1. Initialize Terraform for an Environment

```bash
cd envs/dev
terraform init
```

### 2. Plan Changes

```bash
terraform plan
```

### 3. Apply Changes

```bash
terraform apply
```

### 4. Environment-Specific Variables

Each environment has its own `terraform.tfvars` file with environment-specific settings. You can also override variables:

```bash
terraform apply -var="node_count=5"
```

## Module Usage

The AKS module is located in `modules/aks/` and is referenced by all environments:

```hcl
module "aks" {
  source = "../../modules/aks"
  
  # Module configuration
  cluster_name = var.cluster_name
  location     = var.location
  # ... other configurations
}
```

## Best Practices

1. **State Management**: Each environment should have its own remote state backend
2. **Variable Management**: Use `terraform.tfvars` for non-sensitive values, use environment variables or secret management for sensitive data
3. **Promotion Workflow**: Test changes in dev → staging → prod
4. **Module Versioning**: Consider versioning modules for production stability

## Remote State Configuration (Recommended)

Add a `backend.tf` file to each environment:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstate${environment}"
    container_name       = "tfstate"
    key                  = "aks-${environment}.tfstate"
  }
}
```

## CI/CD Integration

This structure works well with CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Terraform Plan Dev
  run: |
    cd envs/dev
    terraform init
    terraform plan
    
- name: Terraform Apply Dev
  if: github.ref == 'refs/heads/develop'
  run: |
    cd envs/dev
    terraform apply -auto-approve
```

## Migration from Root-Level Configuration

If migrating from a root-level configuration:

1. Copy state file to the appropriate environment directory
2. Update backend configuration
3. Run `terraform init -migrate-state`
4. Verify with `terraform plan` (should show no changes)

## Troubleshooting

### Module Not Found
If you get "Module not installed" errors:
```bash
terraform init -upgrade
```

### State Lock Issues
If using remote state and encounter locks:
```bash
terraform force-unlock <lock-id>
```

### Different Terraform Versions
Use `.terraform-version` file in each environment directory for version management with tools like tfenv.