# Makefile for AKS Terraform Project

.PHONY: help init validate fmt plan apply destroy test test-unit test-integration clean test-security test-deps test-lint test-coverage test-minimal

TERRAFORM_ROOTS := modules/aks examples/basic examples/spark-cluster envs/dev envs/qa envs/staging envs/prod test/fixtures/module test/fixtures/integration
GOFLAGS ?= -mod=readonly
GOLANGCI_LINT_VERSION ?= v2.7.2

help:
	@echo "Available targets:"
	@echo "  init             Initialize all Terraform roots"
	@echo "  validate         Validate all Terraform roots"
	@echo "  fmt              Format Terraform files"
	@echo "  plan             Run the safe module fixture plan"
	@echo "  apply            Apply the production environment"
	@echo "  destroy          Destroy the production environment"
	@echo "  test             Run safe local tests"
	@echo "  test-unit        Run unit tests only"
	@echo "  test-integration Run gated Azure integration tests"
	@echo "  test-security    Run security scans"
	@echo "  clean            Clean up local test artifacts"

init:
	@for dir in $(TERRAFORM_ROOTS); do \
		echo "Initializing $$dir"; \
		terraform -chdir=$$dir init -backend=false -input=false; \
	done

validate: init
	@for dir in $(TERRAFORM_ROOTS); do \
		echo "Validating $$dir"; \
		terraform -chdir=$$dir validate; \
	done

fmt:
	terraform fmt -recursive

plan: validate
	terraform -chdir=test/fixtures/module plan -input=false

apply: validate
	terraform -chdir=envs/prod apply

destroy:
	terraform -chdir=envs/prod destroy

test: fmt validate test-unit

test-unit:
	@echo "Running unit tests..."
	cd test && GOFLAGS=$(GOFLAGS) go test -v -timeout 30m ./unit/...

test-integration:
	@echo "Running integration tests..."
	@echo "WARNING: This will deploy real Azure resources and incur costs!"
	@read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	cd test && RUN_INTEGRATION_TESTS=true go test -v -timeout 90m ./integration/...

test-security:
	@echo "Running security scans..."
	@which checkov > /dev/null || (echo "Please install checkov: pipx install checkov" && exit 1)
	checkov -d . --framework terraform --quiet --soft-fail

test-integration-%:
	@echo "Running integration test: $*"
	cd test && RUN_INTEGRATION_TESTS=true go test -v -timeout 90m ./integration/... -run $*

clean:
	@echo "Cleaning up test artifacts..."
	rm -rf test/vendor
	rm -rf .terraform
	rm -f terraform.tfstate*
	rm -f tfplan*
	rm -f test-plan*.out

test-deps:
	@echo "Installing test dependencies..."
	cd test && GOFLAGS=$(GOFLAGS) go mod download
	@which golangci-lint > /dev/null || go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@$(GOLANGCI_LINT_VERSION)

test-lint:
	@echo "Linting test code..."
	cd test && GOFLAGS=$(GOFLAGS) golangci-lint run

test-coverage:
	@echo "Generating test coverage..."
	cd test && GOFLAGS=$(GOFLAGS) go test -v -coverprofile=coverage.out ./...
	cd test && go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: test/coverage.html"

test-minimal:
	@echo "Running safe module fixture plan..."
	terraform -chdir=test/fixtures/module plan -input=false
