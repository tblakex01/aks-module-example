# Terratest Testing Guide

This directory contains automated tests for the AKS Terraform configuration using [Terratest](https://terratest.gruntwork.io/).

## 📁 Test Structure

```
test/
├── unit/                       # Unit tests (no Azure resources)
│   └── terraform_basic_test.go # Basic validation tests
├── integration/                # Integration tests (deploys real resources)
│   ├── aks_cluster_test.go    # AKS cluster tests
│   ├── network_security_test.go # Network and security tests
│   └── monitoring_test.go      # Monitoring configuration tests
├── fixtures/                   # Test configuration files
│   └── minimal.tfvars         # Minimal test configuration
├── helpers/                    # Test helper functions
│   ├── config.go              # Test configuration helpers
│   └── validation.go          # Validation helper functions
├── go.mod                     # Go module definition
└── README.md                  # This file
```

## 🚀 Quick Start

### Prerequisites

1. **Go 1.21+**: Install from [golang.org](https://golang.org/dl/)
2. **Terraform 1.0+**: Install from [terraform.io](https://www.terraform.io/downloads)
3. **Azure CLI**: Install from [docs.microsoft.com](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
4. **Azure Subscription**: With appropriate permissions

### Running Tests Locally

1. **Install dependencies**:
   ```bash
   cd test
   go mod download
   ```

2. **Set up Azure authentication**:
   ```bash
   az login
   az account set --subscription <your-subscription-id>
   ```

3. **Run unit tests** (no Azure resources):
   ```bash
   go test -v -timeout 30m ./unit/...
   ```

4. **Run integration tests** (deploys real resources):
   ```bash
   # Set environment variable to enable integration tests
   export RUN_INTEGRATION_TESTS=true
   
   # Run all integration tests
   go test -v -timeout 60m ./integration/...
   
   # Run specific test
   go test -v -timeout 45m ./integration/... -run TestAKSClusterDeployment
   ```

## 🧪 Test Categories

### Unit Tests
Fast tests that validate Terraform configuration without deploying resources:
- `TestTerraformBasicValidation`: Validates Terraform syntax
- `TestTerraformPlanWithDefaults`: Tests plan with default values
- `TestTerraformPlanWithCustomValues`: Tests plan with custom values
- `TestRequiredVariables`: Ensures all variables have defaults

### Integration Tests
Tests that deploy real Azure resources:

#### AKS Cluster Tests
- `TestAKSClusterDeployment`: Full cluster deployment and validation
- `TestAKSClusterWithExpressRoute`: Tests ExpressRoute integration

#### Network & Security Tests
- `TestNetworkConfiguration`: Validates VNet, subnets, and NSG
- `TestKeyVaultConfiguration`: Tests Key Vault setup
- `TestPrivateDNSZone`: Validates Private DNS Zone

#### Monitoring Tests
- `TestMonitoringConfiguration`: Validates Log Analytics and Container Insights
- `TestLogAnalyticsRetention`: Tests custom retention settings
- `TestMonitoringAlerts`: Validates alert prerequisites

## ⚙️ Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `RUN_INTEGRATION_TESTS` | Enable integration tests | `false` |
| `RUN_EXPRESSROUTE_TESTS` | Enable ExpressRoute tests | `false` |
| `TEST_LOCATION` | Azure region for tests | `East US` |
| `ARM_SUBSCRIPTION_ID` | Azure subscription ID | Required |
| `ARM_CLIENT_ID` | Service principal ID | For CI/CD |
| `ARM_CLIENT_SECRET` | Service principal secret | For CI/CD |
| `ARM_TENANT_ID` | Azure tenant ID | For CI/CD |

### Test Configuration

Tests use minimal configurations to reduce costs:
- Single node pools (1 node each)
- Smaller VM sizes available
- Shorter retention periods
- Test environment tags

## 🔄 CI/CD Integration

### GitHub Actions
The repository includes a GitHub Actions workflow (`.github/workflows/terraform-test.yml`) that:
1. Validates Terraform formatting and syntax
2. Runs unit tests
3. Runs integration tests (on push to main)
4. Performs security scanning (Checkov, tfsec)
5. Estimates costs (Infracost)
6. Cleans up test resources

### Setting up GitHub Actions

1. Add the following secrets to your repository:
   - `ARM_SUBSCRIPTION_ID`
   - `ARM_CLIENT_ID`
   - `ARM_CLIENT_SECRET`
   - `ARM_TENANT_ID`
   - `INFRACOST_API_KEY` (optional, for cost estimation)

2. The workflow triggers on:
   - Push to main/master branch
   - Pull requests
   - Manual dispatch

## 🛡️ Best Practices

### Writing Tests

1. **Use parallel execution** where possible:
   ```go
   t.Parallel()
   ```

2. **Clean up resources**:
   ```go
   defer terraform.Destroy(t, terraformOptions)
   ```

3. **Use unique names** to avoid conflicts:
   ```go
   uniqueID := strings.ToLower(random.UniqueId())
   ```

4. **Implement retries** for flaky operations:
   ```go
   terraformOptions := &terraform.Options{
       MaxRetries: 3,
       RetryableTerraformErrors: map[string]string{
           ".*timeout.*": "Timeout error occurred",
       },
   }
   ```

### Cost Optimization

- Use minimal configurations (1 node, small VMs)
- Run tests in parallel to reduce duration
- Clean up resources immediately after tests
- Use test tags for easy resource identification

### Debugging Failed Tests

1. **Check test output** for detailed error messages
2. **Review Azure Activity Log** for deployment issues
3. **Inspect resources** in Azure Portal
4. **Run with verbose logging**:
   ```bash
   TF_LOG=DEBUG go test -v ./integration/... -run TestName
   ```

## 📊 Test Coverage

Current test coverage includes:
- ✅ Terraform validation and planning
- ✅ AKS cluster deployment
- ✅ Network configuration (VNet, subnets, NSG)
- ✅ Security features (Key Vault, RBAC)
- ✅ Monitoring setup (Log Analytics, Container Insights)
- ✅ Private cluster configuration
- ✅ Node pool configurations
- ⚠️ ExpressRoute integration (requires hub infrastructure)

## 🆘 Troubleshooting

### Common Issues

1. **Authentication errors**:
   ```bash
   az login --tenant <your-tenant-id>
   az account set --subscription <your-subscription-id>
   ```

2. **Timeout errors**:
   - Increase test timeout: `-timeout 90m`
   - Check Azure service health
   - Verify quota limits

3. **Resource conflicts**:
   - Ensure unique naming
   - Check for orphaned resources
   - Clean up failed deployments

4. **Permission errors**:
   - Verify service principal permissions
   - Check Azure RBAC assignments
   - Ensure subscription access

### Cleanup

If tests fail and leave resources:
```bash
# List test resource groups
az group list --query "[?tags.Purpose=='terratest'].name" -o tsv

# Delete specific resource group
az group delete --name <resource-group-name> --yes --no-wait
```

## 📚 Additional Resources

- [Terratest Documentation](https://terratest.gruntwork.io/)
- [Azure SDK for Go](https://github.com/Azure/azure-sdk-for-go)
- [Testing Terraform with Terratest](https://blog.gruntwork.io/open-sourcing-terratest-a-swiss-army-knife-for-testing-infrastructure-code-5b883336fcd)
- [Azure Terraform Examples](https://github.com/Azure/terraform-azurerm-examples)