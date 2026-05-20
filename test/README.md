# Terratest Testing Guide

This directory contains the Go/Terratest suite for the AKS Terraform module.

## Structure

```
test/
├── fixtures/
│   ├── module/       # Plan-safe module fixture for validation
│   └── integration/  # Real Azure deployment fixture
├── helpers/          # Shared test configuration and Azure validation helpers
├── integration/      # Gated Azure deployment validation
├── unit/             # Fast tests, including terraform test mock-provider runs
├── go.mod
└── go.sum
```

## Prerequisites

- Go 1.26
- Terraform 1.15.x
- Azure CLI or service principal credentials for integration tests only

## Local Commands

```bash
cd test
go mod download
go test -v -timeout 30m ./unit/...
go test -v ./...
```

Unit tests do not require Azure credentials. They run native `terraform test` cases with Terraform's mock provider support, plus Terratest validation of the module fixture.

Integration tests are opt-in because they deploy paid Azure resources:

```bash
export RUN_INTEGRATION_TESTS=true
export TEST_LOCATION="East US"
go test -v -timeout 90m ./integration/...
```

The integration fixture tags every resource group with `Purpose=terratest` and `Temporary=true` so failed runs can be found and removed:

```bash
az group list --query "[?tags.Purpose=='terratest' && tags.Temporary=='true'].name" -o tsv
```

## Coverage

The safe suite validates:

- Terraform syntax for the module fixture.
- Native `terraform test` plan runs using mocked AzureRM resources.
- Fast-fail variable validation for SKU, upgrade channel, network policy, and Spot node-pool settings.
- Cilium network policy/data plane wiring.
- Private DNS zone wiring for private AKS clusters.
- Monitoring enabled and disabled paths without indexing absent `oms_agent` blocks.

The gated integration test validates a real AKS deployment, resource group tags, user-assigned identity, private cluster mode, Azure CNI overlay with Cilium, private DNS zone creation, VNet/subnet configuration, and Log Analytics retention.
