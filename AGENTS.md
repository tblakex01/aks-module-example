# Repository Guidance for Codex Agents

This repository contains Terraform code and Go-based tests for deploying and verifying an Azure Kubernetes Service cluster. The following conventions apply when modifying code here.

## Scope
These instructions apply to the entire repository.

## Formatting
- Run `terraform fmt -recursive` whenever Terraform files (`*.tf`) are changed.
- Run `go fmt ./...` if Go source files under `test/` are modified.

## Linting
- After initializing Terraform (`terraform init`), run `terraform validate` for Terraform code changes.
- For Go code, run `golangci-lint run` or `go vet ./...` when available.

## Testing
- Unit tests are located in `test/unit`. Run `go test ./test/unit/...`.
- Integration tests in `test/integration` require Azure credentials and may incur cost. Run them only when necessary with `RUN_INTEGRATION_TESTS=true go test ./test/integration/...`.

## Workflow
- **Code changes** (Terraform or Go) require running the format, lint, and test steps above before committing.
- **Documentation or comment-only changes** may skip tests and linting.

