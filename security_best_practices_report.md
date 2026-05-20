# Security Best Practices Review: Last Two PRs

Date: 2026-05-20

Reviewed PRs:

- #27: `build(deps): bump ajv and @modelcontextprotocol/sdk`
- #26: `build(deps): bump qs from 6.14.0 to 6.14.2`

## Executive Summary

Both reviewed PRs are stale Dependabot lockfile updates based on `4890d7f`, while current `main` is `8ef0cd7`. They are merge-conflicting and security-regressive compared with current `main`.

Current `main` already carries newer Node dependency state (`@modelcontextprotocol/sdk` 1.29.0, `ajv` 8.20.0, `qs` 6.15.2) and `npm audit --omit=dev --json` reports zero production vulnerabilities. By contrast, the exact PR snapshots report:

- PR #27: 12 production vulnerabilities: 11 high, 1 moderate.
- PR #26: 7 production vulnerabilities: 6 high, 1 moderate.

Recommendation: do not merge either PR. Close them as superseded by current `main`, or have Dependabot recreate/rebase only if a fresh alert remains.

## Scope And Guidance Used

The repository is primarily Terraform with Go tests, plus a Node dependency lockfile for `@upstash/context7-mcp`. The security skill has Go and JavaScript guidance, but no Terraform-specific reference. For these PRs, the relevant reviewed surface is Node supply-chain/dependency hygiene because both PRs modify only `package-lock.json`.

Go guidance checked: dependency hygiene and vulnerability scanning expectations. JavaScript guidance checked: dependency/runtime security and supply-chain-sensitive review. No Go source or Terraform runtime code is changed by either PR.

## Critical Findings

None.

## High Findings

### H-1: PR #27 introduces a lockfile snapshot with known high-severity production vulnerabilities

- Rule ID: JS-SUPPLY-001
- Severity: High
- Location: PR #27 `package-lock.json`, lines 11-24, 90-99, 428-435, 452-455, 589-592, 640-642, 821-824
- Evidence:
  - `@hono/node-server` is locked to 1.19.9 at PR #27 `package-lock.json:11-14`.
  - `@modelcontextprotocol/sdk` is locked to 1.26.0 at PR #27 `package-lock.json:23-30`.
  - `ajv` is locked to 8.18.0 at PR #27 `package-lock.json:90-99`.
  - `express-rate-limit` is locked to 8.2.1 at PR #27 `package-lock.json:428-435`.
  - `fast-uri` is locked to 3.1.0 at PR #27 `package-lock.json:452-455`.
  - `hono` is locked to 4.12.0 at PR #27 `package-lock.json:589-592`.
  - `ip-address` is locked to 10.0.1 at PR #27 `package-lock.json:640-642`.
  - `path-to-regexp` is locked to 8.3.0 at PR #27 `package-lock.json:821-824`.
- Audit result: `npm audit --omit=dev --json` against the exact PR #27 snapshot reported 12 production vulnerabilities: 11 high and 1 moderate.
- Impact: Merging or manually resolving this PR by taking its lockfile can reintroduce vulnerable transitive packages affecting routing, static serving, URL parsing, rate limiting, and Hono/MCP server behavior.
- Fix: Do not merge PR #27. Keep current `main` lockfile or regenerate a fresh lockfile from current `main` with `npm update`/Dependabot recreate, then require `npm audit --omit=dev` to pass.
- Mitigation: Keep CI's `npm ci --ignore-scripts` and `npm audit --omit=dev` checks enabled.
- False positive notes: These are transitive dependencies under `@upstash/context7-mcp`; exploitability depends on how the local MCP package is executed, but dependency alerts are still relevant because this repository installs the production dependency.

### H-2: PR #26 leaves the MCP SDK dependency chain on vulnerable versions

- Rule ID: JS-SUPPLY-001
- Severity: High
- Location: PR #26 `package-lock.json`, lines 11-23, 60-68, 337-345, 718-721, 758-761
- Evidence:
  - `@modelcontextprotocol/sdk` remains locked to 1.12.1 at PR #26 `package-lock.json:11-17`.
  - `ajv` remains locked to 6.12.6 at PR #26 `package-lock.json:60-68`.
  - `express` remains locked to 5.1.0 at PR #26 `package-lock.json:337-345`.
  - `path-to-regexp` remains locked to 8.2.0 at PR #26 `package-lock.json:718-721`.
  - `qs` only moves to 6.14.2 at PR #26 `package-lock.json:758-761`.
- Audit result: `npm audit --omit=dev --json` against the exact PR #26 snapshot reported 7 production vulnerabilities: 6 high and 1 moderate.
- Impact: The PR fixes only part of the dependency graph and leaves higher-impact vulnerabilities in the MCP SDK and routing stack.
- Fix: Do not merge PR #26. Current `main` already supersedes it with `@modelcontextprotocol/sdk` 1.29.0, `ajv` 8.20.0, `express` 5.2.1, and `qs` 6.15.2.
- Mitigation: Close #26 as superseded; let Dependabot open a fresh PR only if current `main` develops a new alert.
- False positive notes: `qs` itself is newer in PR #26 than its original base, but the full production dependency graph remains vulnerable.

### H-3: Both PRs are merge-conflicting and security-regressive relative to current main

- Rule ID: JS-SUPPLY-002
- Severity: High
- Location: PR metadata and current `main` `package-lock.json`, lines 27-49, 94-103, 389-415, 857-860
- Evidence:
  - `gh pr view 27 --json mergeable,mergeStateStatus,baseRefOid,headRefOid` reports `mergeable: CONFLICTING`, `mergeStateStatus: DIRTY`, base `4890d7f`, head `64aa42b`.
  - `gh pr view 26 --json mergeable,mergeStateStatus,baseRefOid,headRefOid` reports `mergeable: CONFLICTING`, `mergeStateStatus: DIRTY`, base `4890d7f`, head `de93d1f`.
  - Current `main` locks `@modelcontextprotocol/sdk` 1.29.0 at `package-lock.json:27-30`.
  - Current `main` locks `ajv` 8.20.0 at `package-lock.json:94-103`.
  - Current `main` locks `express` 5.2.1 at `package-lock.json:389-415`.
  - Current `main` locks `qs` 6.15.2 at `package-lock.json:857-860`.
- Impact: A manual conflict resolution that takes either PR lockfile would downgrade security posture compared with current `main`.
- Fix: Close both PRs as superseded. If GitHub still reports Dependabot alerts after closure, recreate from current `main` and review the new diff only.
- Mitigation: Treat stale Dependabot PRs as unsafe until audited against the current base branch.
- False positive notes: GitHub already prevents direct merge because both PRs are conflicting; the risk is manual resolution or accidental rebase that preserves stale vulnerable versions.

## Medium Findings

### M-1: Terraform security scan was skipped on both PRs because the validate job failed

- Rule ID: CI-SEC-001
- Severity: Medium
- Location: `.github/workflows/terraform-test.yml`, lines 53-60 and 161-175
- Evidence:
  - `Validate Terraform` failed for both PRs.
  - `Security Scan` was skipped for both PRs.
  - The workflow defines `security-scan` with `needs: validate` at `.github/workflows/terraform-test.yml:161-164`.
  - The Checkov scan runs with `soft_fail: true` at `.github/workflows/terraform-test.yml:169-175`.
- Impact: For these dependency-only PRs, the skipped Terraform scan is not the primary risk, but it means the PR check suite did not complete its configured security workflow.
- Fix: Do not use these PRs as merge candidates. For future Terraform-affecting PRs, ensure validation succeeds so Checkov actually runs; consider whether `soft_fail: true` is still the desired policy for production infrastructure.
- Mitigation: Continue running local/package-specific audits for dependency PRs, as done here.
- False positive notes: Neither PR changes Terraform code, so skipped Checkov does not directly hide a Terraform diff issue in these two PRs.

## Low Findings

None.

## Positive Observations

- Current `main` has a `private: true` package and Node engine bound in `package.json`.
- Current CI installs Node dependencies with `npm ci --ignore-scripts`, reducing install-script supply-chain risk.
- Current `main` passed `npm audit --omit=dev --json` locally with zero production vulnerabilities.

## Validation Commands Run

```sh
gh pr list --state all --limit 2 --json number,title,state,mergedAt,updatedAt,headRefName,baseRefName,url,author
gh pr view 27 --json number,title,body,mergeStateStatus,reviewDecision,statusCheckRollup,commits,files,url
gh pr view 26 --json number,title,body,mergeStateStatus,reviewDecision,statusCheckRollup,commits,files,url
gh pr diff 27
gh pr diff 26
gh pr checks 27
gh pr checks 26
npm audit --omit=dev --json
```

Additional validation copied the exact PR head `package.json` and `package-lock.json` snapshots into `/private/tmp/aks-pr-security/pr27` and `/private/tmp/aks-pr-security/pr26`, then ran:

```sh
npm audit --omit=dev --json
```
