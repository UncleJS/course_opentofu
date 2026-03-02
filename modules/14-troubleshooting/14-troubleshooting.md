<!--
SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->

# Module 14 — Troubleshooting

[![Module](https://img.shields.io/badge/module-14%20of%2014-blue?style=flat-square)](../..)
[![Difficulty](https://img.shields.io/badge/difficulty-Intermediate-yellow?style=flat-square)](../..)
[![Time](https://img.shields.io/badge/time-60%20min-lightgrey?style=flat-square)](../..)
[![License](https://img.shields.io/badge/license-CC%20BY--NC--SA%204.0-green?style=flat-square)](../../LICENSE)

> Diagnose and fix the most common OpenTofu errors — from syntax mistakes to state corruption — using a set of deliberately broken configurations.

---

## Table of Contents

1. [Troubleshooting Methodology](#1-troubleshooting-methodology)
2. [Reading Error Messages](#2-reading-error-messages)
3. [Broken Config Catalogue](#3-broken-config-catalogue)
4. [State Recovery](#4-state-recovery)
5. [Provider & Init Failures](#5-provider--init-failures)
6. [Debugging Tools](#6-debugging-tools)
7. [Exercises](#7-exercises)
8. [Further Reading](#8-further-reading)

---

## 1. Troubleshooting Methodology

Follow this decision tree when an OpenTofu command fails:

```
Error message?
├── "Error: Invalid reference" / "Unsupported attribute"
│     → Module 14 § 3.1 — reference errors
├── "Error: Cycle"
│     → Module 14 § 3.2 — circular dependency
├── "Error: Missing required argument"
│     → Module 14 § 3.3 — missing required fields
├── "Error: Error acquiring the state lock"
│     → Module 14 § 4 — state lock stuck
├── "Error: Failed to query available provider packages"
│     → Module 14 § 5 — provider / init failure
└── Unexpected plan diff / drift
      → Module 14 § 6 — debug mode
```

**Always start with:**
```bash
tofu validate   # catch syntax/reference errors without network calls
tofu plan       # see the full error in context
TF_LOG=DEBUG tofu plan 2>debug.log   # full debug output
```

[↑ Back to Table of Contents](#table-of-contents)

---

## 2. Reading Error Messages

OpenTofu error messages follow a consistent structure:

```
╷
│ Error: Invalid reference
│
│   on main.tf line 12, in resource "local_file" "config":
│   12:   content = local_file.other.contnet
│                   ────────────────────────
│
│ A managed resource "local_file" "other" has not been declared.
╵
```

| Part | Meaning |
|---|---|
| `Error:` line | The error category |
| `on main.tf line 12` | Exact file and line number |
| The highlighted expression | What OpenTofu tried to evaluate |
| The bottom message | What went wrong and sometimes how to fix it |

**Tips:**
- The line number is always accurate — go there first
- `Warning:` messages don't fail the run but should be reviewed
- Multiple errors are shown together — fix the first one first (others may cascade)

[↑ Back to Table of Contents](#table-of-contents)

---

## 3. Broken Config Catalogue

Six deliberately broken configurations live in `examples/broken/`. Each has a `README.md` inside explaining the bug and the fix.

| Directory | Bug type | Symptoms |
|---|---|---|
| `01-typo-reference/` | Attribute name typo | `Unsupported attribute` |
| `02-circular-dependency/` | `depends_on` cycle | `Error: Cycle` |
| `03-missing-required/` | Missing required variable | `No value for required variable` |
| `04-type-mismatch/` | Wrong variable type | `Invalid value for input variable` |
| `05-invalid-count/` | `count` used with `for_each` | `Invalid combination of "count" and "for_each"` |
| `06-bad-backend/` | Backend path points to a file (not a dir) | `Error opening backend` |

See [§ 7 Exercises](#7-exercises) for guided fix instructions.

[↑ Back to Table of Contents](#table-of-contents)

---

## 4. State Recovery

### Stuck state lock

```bash
# Get the lock ID from the error message, then:
tofu force-unlock <LOCK_ID>
```

> Use `force-unlock` only when you are certain no other apply is running. Forcibly unlocking during an in-progress apply can corrupt state.

### Corrupted state file

```bash
# Pull a backup of the current state
tofu state pull > state-backup-$(date +%Y%m%d%H%M%S).json

# If state is corrupt, restore from the backup kept by the backend
# (local backend keeps terraform.tfstate.backup automatically)
cp terraform.tfstate.backup terraform.tfstate
tofu state list   # verify

# For remote backends, check version history in the backend UI
```

### Resource stuck in state after manual deletion

```bash
# Remove it from state without destroying (it's already gone)
tofu state rm resource_type.resource_name

# Then re-apply — OpenTofu will re-create it
tofu apply
```

### Import a resource that was created manually

```bash
# Declarative import (OpenTofu 1.5+):
# Add to main.tf:
#   import {
#     id = "the-real-resource-id"
#     to = resource_type.name
#   }
tofu plan   # generates the import plan
tofu apply  # records the resource in state
```

[↑ Back to Table of Contents](#table-of-contents)

---

## 5. Provider & Init Failures

### `Failed to query available provider packages`

```
Error: Failed to query available provider packages
Could not retrieve the list of available versions for provider hashicorp/aws: ...
```

**Causes & fixes:**

| Cause | Fix |
|---|---|
| No internet access | Use a mirror: `tofu init -plugin-dir=/path/to/mirror` |
| Wrong registry URL | Check `source` in `required_providers` |
| Network proxy | Set `HTTPS_PROXY` env var |
| Stale lock file | Delete `.terraform.lock.hcl` and re-run `tofu init` |

### `Plugin did not respond`

Usually a version mismatch between the installed provider and the lock file:

```bash
rm -rf .terraform .terraform.lock.hcl
tofu init
```

### `Error: Incompatible provider version`

The installed provider doesn't satisfy the `version` constraint:

```bash
tofu init -upgrade   # fetch the latest version satisfying the constraint
```

[↑ Back to Table of Contents](#table-of-contents)

---

## 6. Debugging Tools

### Verbose logging

```bash
# Log levels: TRACE DEBUG INFO WARN ERROR
export TF_LOG=DEBUG
tofu plan 2>debug.log
grep "Error\|Warn\|panic" debug.log
```

### Trace a specific subsystem

```bash
export TF_LOG_CORE=INFO       # core OpenTofu logic only
export TF_LOG_PROVIDER=DEBUG  # provider plugin communication only
tofu plan
```

### Write logs to a file

```bash
export TF_LOG=DEBUG
export TF_LOG_PATH=/tmp/tofu-debug.log
tofu apply
```

### Inspect the plan file

```bash
tofu plan -out=plan.bin
tofu show -json plan.bin | jq '.resource_changes[] | select(.change.actions != ["no-op"])'
```

### Graph the dependency chain

```bash
tofu graph | dot -Tsvg > /tmp/graph.svg
# Open graph.svg in a browser to visualise the DAG
```

### Check what a reference resolves to

```bash
# Add a temporary output to main.tf:
output "debug_value" {
  value = some_resource.name.attribute
}
tofu plan   # shows the resolved value in the output diff
# Remove the debug output when done
```

[↑ Back to Table of Contents](#table-of-contents)

---

## 7. Exercises

Each exercise asks you to find and fix one broken configuration.

### Exercise 1 — Typo in attribute reference

```bash
cd modules/14-troubleshooting/examples/broken/01-typo-reference
tofu init && tofu plan
# Read the error. Find the typo. Fix it. Re-run tofu plan — should succeed.
```

---

### Exercise 2 — Circular dependency

```bash
cd modules/14-troubleshooting/examples/broken/02-circular-dependency
tofu init && tofu plan
# OpenTofu reports a cycle. Identify which depends_on is wrong. Remove it.
# Hint: the cycle is caused by an unnecessary explicit dependency.
```

---

### Exercise 3 — Missing required variable

```bash
cd modules/14-troubleshooting/examples/broken/03-missing-required
tofu init && tofu plan
# A required variable has no default and is not provided.
# Fix by adding a default OR by passing -var="name=value".
```

---

### Exercise 4 — Type mismatch

```bash
cd modules/14-troubleshooting/examples/broken/04-type-mismatch
tofu init && tofu plan
# A variable expects a number but receives a string.
# Fix the variable default type or the type annotation.
```

---

### Exercise 5 — count + for_each conflict

```bash
cd modules/14-troubleshooting/examples/broken/05-invalid-count
tofu init && tofu plan
# A resource uses both count and for_each.
# Remove one of them to fix the error.
```

---

### Exercise 6 — Bad backend path

```bash
cd modules/14-troubleshooting/examples/broken/06-bad-backend
tofu init
# The backend path is wrong. Read the error, fix the path.
```

[↑ Back to Table of Contents](#table-of-contents)

---

## 8. Further Reading

- [OpenTofu: Debugging](https://opentofu.org/docs/internals/debugging/)
- [OpenTofu: `force-unlock` command](https://opentofu.org/docs/cli/commands/force-unlock/)
- [OpenTofu: `state rm` command](https://opentofu.org/docs/cli/commands/state/rm/)
- [OpenTofu: Error analysis guide (community wiki)](https://github.com/opentofu/opentofu/discussions)
- [Common Terraform/OpenTofu Errors and Fixes (blog)](https://developer.hashicorp.com/terraform/language/state/backends)
- [TF_LOG environment variable reference](https://opentofu.org/docs/internals/debugging/#enabling-detailed-logs)

[↑ Back to Table of Contents](#table-of-contents)


---

<sub>© 2026 UncleJS & Course OpenTofu contributors — licensed under [CC BY-NC-SA 4.0](../../LICENSE).<br>
You may share and adapt this material for non-commercial purposes with attribution.<br>
SPDX-License-Identifier: CC-BY-NC-SA-4.0</sub>