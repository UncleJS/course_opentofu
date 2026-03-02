<!--
SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->

# Module 13 — Healthcheck

[![Module](https://img.shields.io/badge/module-13%20of%2014-blue?style=flat-square)](../..)
[![Difficulty](https://img.shields.io/badge/difficulty-Intermediate-yellow?style=flat-square)](../..)
[![Time](https://img.shields.io/badge/time-60%20min-lightgrey?style=flat-square)](../..)
[![License](https://img.shields.io/badge/license-CC%20BY--NC--SA%204.0-green?style=flat-square)](../../LICENSE)

> Validate a full OpenTofu project for correctness, drift, security smells, and dependency hygiene — using the built-in CLI and a companion shell script.

---

## Table of Contents

1. [What is an IaC Healthcheck?](#1-what-is-an-iac-healthcheck)
2. [Built-in Healthcheck Commands](#2-built-in-healthcheck-commands)
3. [The `healthcheck.sh` Script](#3-the-healthchecksh-script)
4. [Security Smell Detection](#4-security-smell-detection)
5. [State Health](#5-state-health)
6. [Dependency & Version Hygiene](#6-dependency--version-hygiene)
7. [Integrating into CI](#7-integrating-into-ci)
8. [Exercises](#8-exercises)
9. [Further Reading](#9-further-reading)

---

## 1. What is an IaC Healthcheck?

A healthcheck is a **non-destructive audit** of your OpenTofu project that answers:

| Question | Checked by |
|---|---|
| Does the code parse and validate? | `tofu validate` |
| Is the code consistently formatted? | `tofu fmt -check` |
| Is the state in sync with reality? | `tofu plan -detailed-exitcode` |
| Are there security anti-patterns? | grep / custom scripts |
| Are provider versions pinned? | parse `versions.tf` |
| Are there stale resources in state? | `tofu state list` analysis |
| Are outputs documented? | parse `outputs.tf` |

Run a healthcheck:
- Before every PR merge
- On a schedule (nightly drift detection)
- After a cloud incident (was infrastructure modified out-of-band?)
- Before a major OpenTofu version upgrade

[↑ Back to Table of Contents](#table-of-contents)

---

## 2. Built-in Healthcheck Commands

```bash
# 1. Format check — fail if any file is not canonical format
tofu fmt -check -recursive .

# 2. Validate — check syntax and references (no network calls)
tofu init -backend=false
tofu validate

# 3. Plan — detect real drift (requires backend access)
tofu plan -detailed-exitcode -out=/dev/null
# exit 0 = no changes, exit 2 = drift detected

# 4. State list — inventory what OpenTofu manages
tofu state list

# 5. Show providers — verify pinned versions
tofu providers

# 6. Check for sensitive outputs (grep — not a tofu command)
grep -r 'sensitive\s*=\s*false' . --include="*.tf"

# 7. Visualise dependency graph
tofu graph | dot -Tsvg > /tmp/graph.svg
```

[↑ Back to Table of Contents](#table-of-contents)

---

## 3. The `healthcheck.sh` Script

The companion script `examples/healthcheck.sh` automates all the checks above and produces a colour-coded summary report. See the [examples directory](./examples/) to run it:

```bash
cd modules/13-healthcheck/examples
chmod +x healthcheck.sh
./healthcheck.sh
```

### Output format

```
══════════════════════════════════════════
  OpenTofu Healthcheck
  Directory: /path/to/project
  Date: 2026-01-01 12:00:00
══════════════════════════════════════════

[PASS] fmt: all files are correctly formatted
[PASS] validate: configuration is valid
[PASS] providers: all providers have version constraints
[WARN] plan: 2 resource(s) have pending changes
[PASS] outputs: all outputs have descriptions
[FAIL] security: found hardcoded value in variables.tf:42

══════════════════════════════════════════
  Results: 4 passed  1 warned  1 failed
══════════════════════════════════════════
```

[↑ Back to Table of Contents](#table-of-contents)

---

## 4. Security Smell Detection

Common OpenTofu security anti-patterns to check for:

| Anti-pattern | Detection |
|---|---|
| `sensitive = false` on password/secret outputs | grep `sensitive.*false` in `outputs.tf` |
| Hardcoded secrets in `default = "..."` | grep `default.*password\|secret\|key` |
| `prevent_destroy = false` on critical resources | absence of `prevent_destroy = true` |
| Missing `required_version` constraint | grep `required_version` in `versions.tf` |
| Unconstrained provider versions (`version = "*"`) | grep `version\s*=\s*"\*"` |
| `backend {}` block with credentials in `.tf` | grep `password\|token\|secret` in `backend` block |

> **Note:** For production use, combine these shell checks with dedicated policy engines: [OpenTofu Policy Evaluation](https://opentofu.org/docs/language/policy/), [Checkov](https://www.checkov.io/), or [Trivy](https://trivy.dev/latest/docs/scanner/misconfiguration/).

[↑ Back to Table of Contents](#table-of-contents)

---

## 5. State Health

### Check for stale resources

```bash
# List all resources in state
tofu state list

# Show detail for a specific resource
tofu state show local_file.config

# Pull raw state JSON for analysis
tofu state pull | jq '.resources | length'
tofu state pull | jq '[.resources[].type] | sort | group_by(.) | map({type: .[0], count: length})'
```

### Detect orphaned state

If you delete a resource block from `.tf` but don't run `tofu apply`, the resource stays in state. `tofu plan` will show it as a pending destroy:

```bash
tofu plan | grep "will be destroyed"
```

### Check state serial

A rapidly incrementing state serial can indicate runaway automation or concurrent applies (possible lock bypass):

```bash
tofu state pull | jq '.serial'
```

[↑ Back to Table of Contents](#table-of-contents)

---

## 6. Dependency & Version Hygiene

### Check provider version constraints

Every provider should have:
1. A `source` attribute
2. A `version` constraint using `~>` (pessimistic constraint) — not `*` or `>= 0`

```bash
grep -A3 'required_providers' versions.tf
```

### Check OpenTofu version constraint

```bash
grep 'required_version' versions.tf
```

Should be `>= 1.6.0` or pinned with `~>`.

### Check for lock file

The `.terraform.lock.hcl` file pins exact provider checksums. It should be committed to version control:

```bash
ls -la .terraform.lock.hcl
git status .terraform.lock.hcl
```

### Upgrade providers safely

```bash
# Check for newer versions without applying
tofu init -upgrade

# Review the diff in .terraform.lock.hcl
git diff .terraform.lock.hcl
```

[↑ Back to Table of Contents](#table-of-contents)

---

## 7. Integrating into CI

Add a healthcheck job that runs before plan:

```yaml
# GitHub Actions
healthcheck:
  name: Healthcheck
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: opentofu/setup-opentofu@v1
      with:
        tofu_version: "1.8.0"
    - name: Run healthcheck
      run: |
        chmod +x modules/13-healthcheck/examples/healthcheck.sh
        modules/13-healthcheck/examples/healthcheck.sh modules/YOUR_MODULE/examples
```

The script exits non-zero on any `[FAIL]` result, blocking the pipeline.

[↑ Back to Table of Contents](#table-of-contents)

---

## 8. Exercises

### Exercise 1 — Easy: Run the healthcheck on an existing module

```bash
cd modules/13-healthcheck/examples
chmod +x healthcheck.sh
./healthcheck.sh ../05-state-management/examples
```

Observe which checks pass and which produce warnings.

---

### Exercise 2 — Medium: Introduce and detect a security smell

1. Open `modules/04-variables-and-outputs/examples/variables.tf`
2. Add a variable with `default = "SuperSecret123"` and name it `db_password`
3. Run the healthcheck — it should flag the hardcoded default
4. Fix it by removing the default and marking it `sensitive = true`
5. Re-run the healthcheck — should pass

---

### Exercise 3 — Hard: Custom healthcheck rule

Extend `healthcheck.sh` to add a new rule:

> **Rule:** Every `output` block must have a non-empty `description` attribute.

- Parse all `outputs.tf` files in the target directory
- Fail if any output is missing a description
- Add a `[PASS]` / `[FAIL]` line to the report

[↑ Back to Table of Contents](#table-of-contents)

---

## 9. Further Reading

- [OpenTofu `validate` command](https://opentofu.org/docs/cli/commands/validate/)
- [OpenTofu `fmt` command](https://opentofu.org/docs/cli/commands/fmt/)
- [Checkov — static analysis for IaC](https://www.checkov.io/)
- [Trivy — IaC misconfiguration scanner](https://trivy.dev/latest/docs/scanner/misconfiguration/)
- [tfsec (now part of Trivy)](https://trivy.dev/latest/)
- [OpenTofu Policy Evaluation](https://opentofu.org/docs/language/policy/)

[↑ Back to Table of Contents](#table-of-contents)


---

<sub>© 2026 UncleJS & Course OpenTofu contributors — licensed under [CC BY-NC-SA 4.0](../../LICENSE).<br>
You may share and adapt this material for non-commercial purposes with attribution.<br>
SPDX-License-Identifier: CC-BY-NC-SA-4.0</sub>