<!--
SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->

# Module 10 — CI/CD Integration

[![Module](https://img.shields.io/badge/module-10%20of%2014-blue?style=flat-square)](../..)
[![Difficulty](https://img.shields.io/badge/difficulty-Advanced-red?style=flat-square)](../..)
[![Time](https://img.shields.io/badge/time-90%20min-lightgrey?style=flat-square)](../..)
[![License](https://img.shields.io/badge/license-CC%20BY--NC--SA%204.0-green?style=flat-square)](../../LICENSE)

> Automate OpenTofu across GitHub Actions, GitLab CI, and generic pipelines — with safe plan/apply gates, drift detection, and secret management.

---

## Table of Contents

1. [Why Automate OpenTofu?](#1-why-automate-opentofu)
2. [CI/CD Principles for IaC](#2-cicd-principles-for-iac)
3. [Pipeline Anatomy](#3-pipeline-anatomy)
4. [GitHub Actions Workflow](#4-github-actions-workflow)
5. [GitLab CI Workflow](#5-gitlab-ci-workflow)
6. [Secret Management](#6-secret-management)
7. [Plan Artefacts & Review Gates](#7-plan-artefacts--review-gates)
8. [Drift Detection Jobs](#8-drift-detection-jobs)
9. [Environment Promotion](#9-environment-promotion)
10. [Exercises](#10-exercises)
11. [Further Reading](#11-further-reading)

---

## 1. Why Automate OpenTofu?

Manual `tofu apply` runs are fast to start but brittle at scale:

| Problem | CI/CD Solution |
|---|---|
| Forgotten plan review | Require PR comment or manual approval before apply |
| State drift goes unnoticed | Scheduled `tofu plan` drift-detection job |
| Secrets in shell history | Inject via CI secret stores (no plaintext in logs) |
| Inconsistent versions | Pin `tofu` version with `mise` / `asdf` / container image |
| No audit trail | Pipeline logs + state history = immutable audit log |

> **Under the hood:** OpenTofu is entirely CLI-driven — there is no daemon. A CI job simply installs the binary, authenticates via environment variables, and calls the same commands you run locally. The state backend provides the shared lock that prevents concurrent applies.

[↑ Back to Table of Contents](#table-of-contents)

---

## 2. CI/CD Principles for IaC

### The four pipeline invariants

1. **Plan before apply** — never apply without a saved plan artefact.
2. **Separate stages** — `init → validate → plan → apply` are distinct jobs with explicit dependencies.
3. **Apply only on protected branches** — `main` / `production` trigger apply; feature branches trigger plan only.
4. **State lock is the mutex** — the backend lock prevents two pipelines applying simultaneously. Never use `--lock=false` in CI.

### The golden rule of CI/CD for IaC

> *"Plan in every PR. Apply only on merge."*

This pattern (popularised by Atlantis and adopted by most enterprise pipelines) means:

```
feature-branch  →  tofu plan   (comment plan output on PR)
main            →  tofu apply  (after PR merge, automatically or via manual gate)
```

[↑ Back to Table of Contents](#table-of-contents)

---

## 3. Pipeline Anatomy

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│    init     │────▶│  validate   │────▶│    plan     │────▶│    apply    │
│             │     │  + fmt      │     │ (save plan) │     │ (gate on    │
│ tofu init   │     │ tofu fmt -check   │ tofu plan   │     │  protected  │
│             │     │ tofu validate     │   -out=plan │     │  branch)    │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                                                  │
                                                  ▼
                                         ┌─────────────┐
                                         │   artefact  │
                                         │  plan.bin   │
                                         │  plan.txt   │
                                         └─────────────┘
```

### Stage responsibilities

| Stage | Command | Fails on |
|---|---|---|
| `init` | `tofu init -input=false` | Missing provider, bad backend config |
| `validate` | `tofu fmt -check -recursive` + `tofu validate` | Syntax errors, bad references |
| `plan` | `tofu plan -out=plan.bin` | Resource errors, policy violations |
| `apply` | `tofu apply plan.bin` | Apply failures, state lock conflicts |

> **Under the hood:** `tofu plan -out=plan.bin` serialises the entire execution plan — including provider schemas, resource diffs, and sensitive value hashes — into a binary artefact. `tofu apply plan.bin` executes *exactly* that plan with no re-evaluation. This is why you must pass the saved plan to apply rather than running a fresh plan; otherwise a change pushed between plan and apply could be applied unseen.

[↑ Back to Table of Contents](#table-of-contents)

---

## 4. GitHub Actions Workflow

The workflow below implements the full plan/apply gate pattern. It lives in `.github/workflows/opentofu.yml`.

```yaml
# .github/workflows/opentofu.yml
name: OpenTofu

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  TOFU_VERSION: "1.8.0"
  TF_INPUT: "false"
  TF_IN_AUTOMATION: "true"   # suppresses interactive prompts in logs

jobs:
  # ── init + validate ──────────────────────────────────────────────────────
  validate:
    name: Validate
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install OpenTofu
        uses: opentofu/setup-opentofu@v1
        with:
          tofu_version: ${{ env.TOFU_VERSION }}

      - name: tofu init
        run: tofu init -backend=false   # skip backend for validation
        working-directory: modules/10-cicd-integration/examples

      - name: tofu fmt check
        run: tofu fmt -check -recursive
        working-directory: modules/10-cicd-integration/examples

      - name: tofu validate
        run: tofu validate
        working-directory: modules/10-cicd-integration/examples

  # ── plan ─────────────────────────────────────────────────────────────────
  plan:
    name: Plan
    runs-on: ubuntu-latest
    needs: [validate]
    outputs:
      plan_exitcode: ${{ steps.plan.outputs.exitcode }}
    steps:
      - uses: actions/checkout@v4

      - name: Install OpenTofu
        uses: opentofu/setup-opentofu@v1
        with:
          tofu_version: ${{ env.TOFU_VERSION }}

      - name: tofu init
        run: tofu init
        working-directory: modules/10-cicd-integration/examples
        env:
          # Backend credentials passed as env vars — never hard-coded
          TF_HTTP_USERNAME: ${{ secrets.TF_HTTP_USERNAME }}
          TF_HTTP_PASSWORD: ${{ secrets.TF_HTTP_PASSWORD }}

      - name: tofu plan
        id: plan
        run: |
          tofu plan \
            -out=plan.bin \
            -detailed-exitcode \
            2>&1 | tee plan.txt
          echo "exitcode=${PIPESTATUS[0]}" >> "$GITHUB_OUTPUT"
        working-directory: modules/10-cicd-integration/examples
        continue-on-error: true   # capture exitcode; fail below if needed

      - name: Upload plan artefact
        uses: actions/upload-artifact@v4
        with:
          name: tofu-plan
          path: |
            modules/10-cicd-integration/examples/plan.bin
            modules/10-cicd-integration/examples/plan.txt
          retention-days: 5

      - name: Post plan to PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const plan = fs.readFileSync(
              'modules/10-cicd-integration/examples/plan.txt', 'utf8'
            );
            const body = `## OpenTofu Plan\n\`\`\`hcl\n${plan.slice(0, 65000)}\n\`\`\``;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body
            });

      - name: Fail if plan errored
        if: steps.plan.outputs.exitcode == '1'
        run: exit 1

  # ── apply (main branch only, manual approval via environment) ───────────
  apply:
    name: Apply
    runs-on: ubuntu-latest
    needs: [plan]
    if: |
      github.ref == 'refs/heads/main' &&
      needs.plan.outputs.plan_exitcode == '2'   # 2 = changes present
    environment: production   # requires manual approval in GitHub UI
    steps:
      - uses: actions/checkout@v4

      - name: Install OpenTofu
        uses: opentofu/setup-opentofu@v1
        with:
          tofu_version: ${{ env.TOFU_VERSION }}

      - name: Download plan artefact
        uses: actions/download-artifact@v4
        with:
          name: tofu-plan
          path: modules/10-cicd-integration/examples

      - name: tofu init
        run: tofu init
        working-directory: modules/10-cicd-integration/examples
        env:
          TF_HTTP_USERNAME: ${{ secrets.TF_HTTP_USERNAME }}
          TF_HTTP_PASSWORD: ${{ secrets.TF_HTTP_PASSWORD }}

      - name: tofu apply
        run: tofu apply plan.bin
        working-directory: modules/10-cicd-integration/examples

  # ── drift detection (scheduled) ─────────────────────────────────────────
  drift:
    name: Drift Detection
    runs-on: ubuntu-latest
    if: github.event_name == 'schedule'
    steps:
      - uses: actions/checkout@v4

      - name: Install OpenTofu
        uses: opentofu/setup-opentofu@v1
        with:
          tofu_version: ${{ env.TOFU_VERSION }}

      - name: tofu init
        run: tofu init
        working-directory: modules/10-cicd-integration/examples

      - name: Detect drift
        id: drift
        run: |
          tofu plan -detailed-exitcode -refresh-only 2>&1 | tee drift.txt
          echo "exitcode=${PIPESTATUS[0]}" >> "$GITHUB_OUTPUT"
        working-directory: modules/10-cicd-integration/examples
        continue-on-error: true

      - name: Alert on drift
        if: steps.drift.outputs.exitcode == '2'
        run: |
          echo "::warning::Infrastructure drift detected! Review drift.txt"
          cat modules/10-cicd-integration/examples/drift.txt
          exit 1
```

### Key flags explained

| Flag | Purpose |
|---|---|
| `-input=false` | Fail instead of waiting for interactive input |
| `TF_IN_AUTOMATION=true` | Suppresses "Learn more" hints in log output |
| `-detailed-exitcode` | Exit 0 = no changes, 1 = error, 2 = changes present |
| `-refresh-only` | Plan only state refresh — useful for drift detection |
| `environment: production` | GitHub environment gate: requires named approvers |

[↑ Back to Table of Contents](#table-of-contents)

---

## 5. GitLab CI Workflow

```yaml
# .gitlab-ci.yml
variables:
  TOFU_VERSION: "1.8.0"
  TF_IN_AUTOMATION: "true"
  TF_INPUT: "false"
  WORKDIR: "modules/10-cicd-integration/examples"

stages:
  - validate
  - plan
  - apply

default:
  image: ghcr.io/opentofu/opentofu:${TOFU_VERSION}
  before_script:
    - cd ${WORKDIR}

# ── validate ──────────────────────────────────────────────────────────────
validate:
  stage: validate
  script:
    - tofu init -backend=false
    - tofu fmt -check -recursive
    - tofu validate
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH'

# ── plan ──────────────────────────────────────────────────────────────────
plan:
  stage: plan
  script:
    - tofu init
    - tofu plan -out=plan.bin 2>&1 | tee plan.txt
  artifacts:
    name: tofu-plan-${CI_COMMIT_SHORT_SHA}
    paths:
      - ${WORKDIR}/plan.bin
      - ${WORKDIR}/plan.txt
    expire_in: 1 week
    reports:
      # GitLab renders the plan as a MR widget when using the Terraform report type
      terraform: ${WORKDIR}/plan.txt
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH'

# ── apply ─────────────────────────────────────────────────────────────────
apply:
  stage: apply
  script:
    - tofu init
    - tofu apply plan.bin
  dependencies:
    - plan
  environment:
    name: production
  rules:
    - if: '$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH'
      when: manual   # requires a human to click "Run" in the GitLab UI
  allow_failure: false
```

> **Note:** GitLab has built-in OpenTofu/Terraform state management at
> `https://gitlab.example.com/api/v4/projects/<id>/terraform/state/<name>`.
> Use the `http` backend with `TF_HTTP_*` environment variables populated
> from GitLab CI variables — no external state store required.

[↑ Back to Table of Contents](#table-of-contents)

---

## 6. Secret Management

### What should never appear in `.tf` files or pipeline logs

- Cloud provider credentials (`AWS_ACCESS_KEY_ID`, etc.)
- Backend tokens
- State encryption passphrases
- API keys written into resource attributes

### Injection patterns (safest → least safe)

| Pattern | How | Risk |
|---|---|---|
| OIDC / Workload Identity | Cloud-native, no static credentials | Best |
| CI secret store → env var | `TF_VAR_foo=${{ secrets.FOO }}` | Good |
| Vault dynamic secrets | `vault read` before `tofu apply` | Good |
| `.tfvars` file in CI artefact | File encrypted at rest | Acceptable |
| Plaintext in `.tf` file | ❌ Never | ❌ |

### OpenTofu-specific secret env vars

```bash
# Any TF_VAR_* env var is mapped to the corresponding input variable
export TF_VAR_db_password="$SECRET_FROM_VAULT"

# Backend credentials
export TF_HTTP_USERNAME="gitlab-ci-token"
export TF_HTTP_PASSWORD="$CI_JOB_TOKEN"

# Disable colour in CI logs
export TF_CLI_ARGS="-no-color"
```

> **Under the hood:** OpenTofu reads `TF_VAR_*` variables during the variable evaluation phase (before plan). They are treated identically to `-var` flags. Sensitive values are hashed in the state (not stored plaintext) but **are** stored encrypted in plan artefacts — protect plan.bin as you would a secret.

[↑ Back to Table of Contents](#table-of-contents)

---

## 7. Plan Artefacts & Review Gates

### Why save the plan binary?

```
tofu plan -out=plan.bin   # serialise the plan
# ... human reviews plan.txt ...
tofu apply plan.bin       # apply EXACTLY what was planned
```

If you run `tofu apply` without a saved plan, OpenTofu computes a **new** plan at apply time. Any infrastructure change made between plan and apply (by a human or another pipeline) would be applied unseen — a serious safety hazard in production.

### Plan output codes for scripting

```bash
tofu plan -detailed-exitcode -out=plan.bin
case $? in
  0) echo "No changes"   ;;
  1) echo "Plan error"   ; exit 1 ;;
  2) echo "Changes found"; apply_or_gate ;;
esac
```

### Human-readable plan

```bash
# Convert binary plan to text for PR comments / code review
tofu show -no-color plan.bin > plan.txt
```

[↑ Back to Table of Contents](#table-of-contents)

---

## 8. Drift Detection Jobs

Infrastructure drift occurs when the real state of your resources differs from what OpenTofu's state file records. Common causes:

- Manual changes via cloud console
- Other automation tools modifying the same resources
- Provider-side changes (e.g. AWS auto-assigns tags)

### Detecting drift in CI

```yaml
# Run nightly at 02:00 UTC
on:
  schedule:
    - cron: '0 2 * * *'
```

```bash
# -refresh-only: only refresh state, don't compute resource changes
tofu plan -refresh-only -detailed-exitcode
# exit 2 = state is out of sync with real infrastructure
```

### Remediation options

| Situation | Action |
|---|---|
| Drift is intentional (someone fixed a prod incident manually) | `tofu apply -refresh-only` to sync state |
| Drift should be reverted (runaway change) | `tofu apply` (without -refresh-only) to revert |
| Drift is partial | `tofu apply -target=resource.name` |

[↑ Back to Table of Contents](#table-of-contents)

---

## 9. Environment Promotion

A robust IaC pipeline promotes the same plan through environments:

```
dev branch ──▶ tofu apply (auto)  ──▶ dev environment
               │
               ▼ (tests pass)
staging tag ──▶ tofu apply (auto)  ──▶ staging environment
               │
               ▼ (smoke tests pass)
main tag    ──▶ tofu apply (manual gate) ──▶ prod environment
```

### Implementation with workspaces

```bash
# Each environment is a separate workspace with its own state
tofu workspace select dev    && tofu apply -var-file=envs/dev.tfvars
tofu workspace select staging && tofu apply -var-file=envs/staging.tfvars
tofu workspace select prod    && tofu apply -var-file=envs/prod.tfvars
```

### Implementation with separate state keys

```bash
# Alternatively, separate backend paths (no workspaces)
tofu init -backend-config="path=states/dev/terraform.tfstate"
tofu init -backend-config="path=states/prod/terraform.tfstate"
```

> The second approach (separate state keys) is generally preferred for strict environment isolation — workspace state is stored in the same backend location, which can complicate access control.

[↑ Back to Table of Contents](#table-of-contents)

---

## 10. Exercises

### Exercise 1 — Easy: Validate in CI (local simulation)

**Goal:** Simulate the validate stage of a CI pipeline locally.

```bash
cd modules/10-cicd-integration/examples
tofu init -backend=false
tofu fmt -check -recursive ../..
tofu validate
echo "Validate stage: PASSED"
```

**Challenge:** Introduce a deliberate syntax error in `main.tf` and observe the validate stage catch it. Fix it and re-run.

---

### Exercise 2 — Medium: Plan/Apply Gate

**Goal:** Implement the plan → human review → apply workflow.

```bash
cd modules/10-cicd-integration/examples
tofu init

# Step 1: plan and save
tofu plan -out=plan.bin -detailed-exitcode; PLAN_EXIT=$?
echo "Plan exit code: $PLAN_EXIT"   # 0=no changes, 2=changes

# Step 2: review the plan (human step)
tofu show plan.bin

# Step 3: apply only if changes exist
if [ "$PLAN_EXIT" -eq 2 ]; then
  read -p "Apply these changes? (yes/no): " CONFIRM
  [ "$CONFIRM" = "yes" ] && tofu apply plan.bin
fi
```

**Challenge:** Add a `TF_VAR_resource_count=5` environment variable and observe it flow into the plan without touching any `.tf` file.

---

### Exercise 3 — Hard: Drift Detection Pipeline

**Goal:** Simulate infrastructure drift and build a detection + remediation flow.

```bash
cd modules/10-cicd-integration/examples
tofu init && tofu apply -auto-approve

# Simulate drift: delete a managed file outside of OpenTofu
rm /tmp/tofu-cicd-demo/dev/consumer.json

# Detect drift
tofu plan -detailed-exitcode; echo "Exit: $?"
# Should exit 2 — OpenTofu detects the missing file

# Option A: remediate by re-applying
tofu apply -auto-approve

# Option B: accept the drift (sync state without reverting)
# tofu apply -refresh-only -auto-approve

# Verify
tofu plan -detailed-exitcode; echo "Exit: $?"   # should be 0 now
```

**Challenge:** Write a shell script `drift-check.sh` that:
1. Runs `tofu plan -refresh-only -detailed-exitcode`
2. Exits 0 if no drift
3. Prints a formatted drift report if exit code 2
4. Fails the script with a non-zero exit code (for CI integration)

[↑ Back to Table of Contents](#table-of-contents)

---

## 11. Further Reading

- [OpenTofu CI/CD Guide (official docs)](https://opentofu.org/docs/language/settings/backends/configuration/)
- [opentofu/setup-opentofu GitHub Action](https://github.com/opentofu/setup-opentofu)
- [GitLab Terraform/OpenTofu State backend docs](https://docs.gitlab.com/ee/user/infrastructure/iac/terraform_state.html)
- [Atlantis — Pull Request Automation for Terraform/OpenTofu](https://www.runatlantis.io/)
- [Spacelift — OpenTofu CI/CD platform](https://spacelift.io/opentofu)
- [Using TF_IN_AUTOMATION (HashiCorp/OpenTofu)](https://opentofu.org/docs/cli/config/environment-variables/#tf_in_automation)

[↑ Back to Table of Contents](#table-of-contents)


---

<sub>© 2026 UncleJS & Course OpenTofu contributors — licensed under [CC BY-NC-SA 4.0](../../LICENSE).<br>
You may share and adapt this material for non-commercial purposes with attribution.<br>
SPDX-License-Identifier: CC-BY-NC-SA-4.0</sub>