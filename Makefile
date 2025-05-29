# Makefile for AKS Terraform Project

.PHONY: help init validate fmt plan apply destroy test test-unit test-integration clean

# Default target
help:
	@echo "Available targets:"
	@echo "  init             Initialize Terraform"
	@echo "  validate         Validate Terraform configuration"
	@echo "  fmt              Format Terraform files"
	@echo "  plan             Run Terraform plan"
	@echo "  apply            Apply Terraform configuration"
	@echo "  destroy          Destroy Terraform resources"
	@echo "  test             Run all tests"
	@echo "  test-unit        Run unit tests only"
	@echo "  test-integration Run integration tests"
	@echo "  test-security    Run security scans"
	@echo "  clean            Clean up test artifacts"

# Terraform commands
init:
	terraform init

validate: init
	terraform validate

fmt:
	terraform fmt -recursive

plan: validate
	terraform plan

apply: validate
	terraform apply

destroy:
	terraform destroy

# Testing commands
test: test-unit test-integration

test-unit:
	@echo "Running unit tests..."
	cd test && go test -v -timeout 30m ./unit/...

test-integration:
	@echo "Running integration tests..."
	@echo "WARNING: This will deploy real Azure resources and incur costs!"
	@read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	cd test && RUN_INTEGRATION_TESTS=true go test -v -timeout 60m ./integration/...

test-security:
	@echo "Running security scans..."
	@which tfsec > /dev/null || (echo "Installing tfsec..." && go install github.com/aquasecurity/tfsec/cmd/tfsec@latest)
	tfsec . --soft-fail
	@which checkov > /dev/null || (echo "Please install checkov: pip install checkov" && exit 1)
	checkov -d . --framework terraform --quiet

# Test a specific integration test
test-integration-%:
	@echo "Running integration test: $*"
	cd test && RUN_INTEGRATION_TESTS=true go test -v -timeout 45m ./integration/... -run $*

# Clean up
clean:
	@echo "Cleaning up test artifacts..."
	rm -rf test/vendor
	rm -rf .terraform
	rm -f terraform.tfstate*
	rm -f .terraform.lock.hcl
	rm -f tfplan*
	rm -f test-plan*.out

# Install test dependencies
test-deps:
	@echo "Installing test dependencies..."
	cd test && go mod download
	@which tfsec > /dev/null || go install github.com/aquasecurity/tfsec/cmd/tfsec@latest
	@which golangci-lint > /dev/null || go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# Lint Go test code
test-lint:
	@echo "Linting test code..."
	cd test && golangci-lint run

# Generate test coverage
test-coverage:
	@echo "Generating test coverage..."
	cd test && go test -v -coverprofile=coverage.out ./...
	cd test && go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: test/coverage.html"

# Run minimal test deployment
test-minimal:
	@echo "Running minimal test deployment..."
	terraform plan -var-file=test/fixtures/minimal.tfvars