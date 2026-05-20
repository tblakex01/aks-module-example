# Security Best Practices Review: Last Five Main Commits

Date: 2026-05-20

Reviewed range: `dfa7bced45fca43fb0f8f08480f809323c348cf3..8ef0cd7013d30c1e48e97fef864c5d2dd379253f` (`main~5..main`)

Reviewed commits:

- `8ef0cd7` `chore: update node lts tooling`
- `62c1814` `fix: add linux terraform provider checksums`
- `e2f3b5a` `fix: modernize aks module and tests`
- `4890d7f` `Merge pull request #11 from tblakex01/dependabot/npm_and_yarn/body-parser-2.2.1`
- `9af0e45` `Merge pull request #1 from tblakex01/dependabot/go_modules/test/github.com/Azure/azure-sdk-for-go/sdk/azidentity-1.6.0`

## Executive Summary

The last five commits improve several security-relevant defaults: private AKS API endpoint defaults, public private-cluster FQDN disabled by default, Azure RBAC enabled in environment fixtures, workload identity/OIDC enabled, Key Vault soft delete and purge protection, Node lockfile modernization, `npm ci --ignore-scripts`, and a clean production `npm audit`.

The main issues are Terraform/Azure hardening gaps. Local Checkov reported 29 Terraform failures, with the most important production findings around Key Vault public network access and AKS local admin credentials. These are not dependency vulnerabilities, but they are material infrastructure security controls for a production AKS module.

Remediation status: the High and Medium findings in this report were addressed in the follow-up security hardening change. Post-fix validation shows Checkov passing with zero failures.

## Scope And Guidance Used

The requested skill has Go and JavaScript references, but no Terraform-specific reference. I used the Go/JavaScript references for test/dependency/CI review and used Checkov plus Azure AKS/Key Vault secure-default review for Terraform-specific findings.

## Critical Findings

None.

## High Findings

### H-1: Key Vault data-plane access is not network-restricted

- Rule ID: AZURE-KV-NET-001
- Severity: High
- Location: `envs/dev/main.tf`, `envs/qa/main.tf`, `envs/staging/main.tf`, `envs/prod/main.tf` lines 189-212; module optional Key Vault at `modules/aks/security.tf` lines 2-12
- Evidence: The environment Key Vault resources set soft delete and purge protection, but do not set `public_network_access_enabled = false` and do not define `network_acls`. Checkov reported CKV_AZURE_189 and CKV_AZURE_109 for each environment Key Vault.
- Impact: The Key Vault endpoint remains publicly reachable. Azure authentication is still required, but the missing network boundary increases blast radius if an identity or access policy is compromised.
- Fix: Add one canonical Key Vault network policy to the module/environment path: disable public network access and use private endpoints, or restrict `network_acls` to approved subnets/IPs. Keep purge protection enabled.
- Mitigation: Until fixed, audit Key Vault access policies/RBAC assignments and confirm no broad principals can read secrets.

### H-2: AKS local admin account is not disabled

- Rule ID: AZURE-AKS-AUTH-001
- Severity: High
- Location: `modules/aks/main.tf` lines 47-58 and 111-113
- Evidence: The cluster enables private networking and Azure RBAC, but the `azurerm_kubernetes_cluster` resource does not set `local_account_disabled = true`. Checkov reported CKV_AZURE_141.
- Impact: Local admin credentials can bypass the intended Azure AD RBAC boundary if exposed through state, outputs, operator workstations, or automation logs.
- Fix: Set `local_account_disabled = true` in the canonical AKS resource and adjust kubeconfig outputs/tests to rely on Azure AD-authenticated access instead of local admin credentials.
- Mitigation: Restrict Terraform state access tightly and avoid emitting kubeconfig material outside controlled automation.

## Medium Findings

### M-1: Node pool host encryption is disabled or not enforced

- Rule ID: AZURE-AKS-ENCRYPT-001
- Severity: Medium
- Location: `envs/prod/main.tf` lines 252-265; `modules/aks/main.tf` lines 60-80 and 175-195
- Evidence: The production Spark node pool explicitly sets `enable_host_encryption = false`; the module forwards this to `host_encryption_enabled` for additional pools, and the system pool has no equivalent setting. Checkov reported CKV_AZURE_227 and related AKS encryption checks.
- Impact: Temporary disks, caches, and host-side data paths may not receive the expected host-level encryption posture for production workloads.
- Fix: Add a system-pool host-encryption input, default production pools to host encryption where VM sizes support it, and validate or document exceptions. Consider adding disk encryption set support if customer-managed key policy is required.

### M-2: Terraform security scanning is advisory-only

- Rule ID: CI-SEC-001
- Severity: Medium
- Location: `.github/workflows/terraform-test.yml` lines 169-176
- Evidence: Checkov runs with `soft_fail: true`, so the current 29 Checkov failures do not fail CI. The reviewed workflow also removed the previous tfsec action.
- Impact: Security regressions can merge even when the configured scanner detects them.
- Fix: Make Checkov blocking once existing findings are triaged, or add narrow inline suppressions with documented reasons and keep new unsuppressed failures blocking.

### M-3: Cloud credentials are scoped as global workflow environment variables

- Rule ID: CI-SECRETS-001
- Severity: Medium
- Location: `.github/workflows/terraform-test.yml` lines 16-24
- Evidence: `ARM_CLIENT_SECRET`, ARM IDs, and `INFRACOST_API_KEY` are defined at workflow scope, making them available to jobs that do not need deployment credentials.
- Impact: Any compromised or overly broad job step has unnecessary access to cloud credentials. `npm ci --ignore-scripts` helps, but least privilege should not rely on package install behavior alone.
- Fix: Move Azure credentials to the specific Azure Login/integration/cleanup steps that need them. Prefer GitHub OIDC federated Azure login over a long-lived `ARM_CLIENT_SECRET`.

## Low Findings

None.

## Positive Observations

- `npm audit --omit=dev` reports zero vulnerabilities on current `main`.
- CI uses `npm ci --ignore-scripts`.
- Terraform formatting passes.
- Go tests pass when Terraform 1.15.3 is selected through tfenv.
- `golangci-lint run` reports zero issues.
- AKS defaults include private cluster enabled, public private-cluster FQDN disabled, Azure RBAC in env fixtures, workload identity/OIDC, Azure Policy, monitoring, and Cilium network policy/data plane.

## Validation Commands Run

```sh
gh pr close 27 --comment "Closing as superseded by current main..."
gh pr close 26 --comment "Closing as superseded by current main..."
gh pr view 27 --json number,state,url
gh pr view 26 --json number,state,url
git diff --stat main~5..main
git diff --name-status main~5..main
npm audit --omit=dev
terraform fmt -check -recursive
checkov -d . --framework terraform --quiet --compact
GOCACHE=/private/tmp/aks-go-cache TFENV_TERRAFORM_VERSION=1.15.3 go test ./...
GOCACHE=/private/tmp/aks-go-cache GOLANGCI_LINT_CACHE=/private/tmp/aks-golangci-cache golangci-lint run
```

Validation results:

- PR #27 and PR #26 are now closed.
- `npm audit --omit=dev`: passed, zero vulnerabilities.
- `terraform fmt -check -recursive`: passed.
- Initial `checkov -d . --framework terraform --quiet --compact`: failed, 29 Terraform findings.
- Post-fix `checkov -d . --framework terraform --quiet --compact`: passed, zero failures.
- `go test ./...`: passed with Terraform 1.15.3 selected through tfenv.
- `golangci-lint run`: passed, zero issues.
- `govulncheck` was not installed locally.
