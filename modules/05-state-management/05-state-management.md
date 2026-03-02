# Module 05 — State Management

<!-- SPDX-License-Identifier: CC-BY-NC-SA-4.0 -->

[![Module](https://img.shields.io/badge/Module-05-blue)](.)
[![Difficulty](https://img.shields.io/badge/Difficulty-Intermediate-yellow)](.)
[![Time](https://img.shields.io/badge/Time-90%20min-lightgrey)](.)
[![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)

---

## Table of Contents

- [Overview](#overview)
- [What is State and Why It Exists](#what-is-state-and-why-it-exists)
- [State File Internals](#state-file-internals)
- [The Plan/Refresh Cycle in Detail](#the-planrefresh-cycle-in-detail)
- [State Backends](#state-backends)
- [State Locking](#state-locking)
- [State Operations](#state-operations)
- [State Drift](#state-drift)
- [State Surgery](#state-surgery)
- [Exercises](#exercises)
- [Further Reading](#further-reading)
- [Summary](#summary)
- [Next Module →](#next-module-)

---

## Overview

State is the cornerstone of how OpenTofu tracks and manages infrastructure. Without state, OpenTofu could not know what resources it manages, whether they have drifted from the desired configuration, or how to safely modify or remove them.

This module is one of the most important in the course. A thorough understanding of state prevents data loss, runaway destroy operations, and the confusion that comes from state corruption or drift.

By the end of this module you will be able to:
- Explain the state file's JSON structure and every important field
- Understand the plan/refresh/diff pipeline in full detail
- Configure local and remote backends
- Use all `tofu state` subcommands safely
- Detect and remediate configuration drift
- Perform state surgery operations (mv, rm, import, push) with confidence

↑ [Back to Table of Contents](#table-of-contents)

---

## What is State and Why It Exists

### The Core Problem

OpenTofu manages infrastructure declaratively. You describe the desired end state, and OpenTofu figures out what changes to make. But to figure out what changes are needed, OpenTofu must know:

1. What resources it currently manages
2. What their current attribute values are
3. What the relationship is between HCL resource addresses and real-world resource IDs

The **state file** (`terraform.tfstate`) is the answer to all three questions. It is a JSON document that maps every resource address (e.g., `local_file.config`) to its real-world attributes (e.g., `filename = "/tmp/config.txt"`, `id = "abc123"`).

### Why Not Always Query the Provider?

A common question: why not just query the provider on every run instead of maintaining state?

| Reason | Explanation |
|---|---|
| **Performance** | Querying 500 resources on every plan would be very slow |
| **Provider limitations** | Not all resources expose a "list all" API |
| **Relationship tracking** | State records which HCL address owns which real resource ID |
| **Metadata** | State stores data that providers do not expose (e.g., dependencies, schema version) |

### What State Tracks

For each managed resource, state records:
- The **resource address** (`local_file.config`)
- The **provider** that manages it (`registry.terraform.io/hashicorp/local`)
- The **schema version** of the resource at creation time
- All **attribute values** (both input arguments and computed attributes)
- The **dependencies** — what other resources this resource depended on

↑ [Back to Table of Contents](#table-of-contents)

---

## State File Internals

The state file is a JSON document. Understanding its structure helps you diagnose problems and perform safe state surgery.

### Top-Level Structure

```json
{
  "version": 4,
  "terraform_version": "1.8.0",
  "serial": 7,
  "lineage": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "outputs": {
    "file_path": {
      "value": "/tmp/hello.txt",
      "type": "string"
    }
  },
  "resources": [ ... ],
  "check_results": null
}
```

| Field | Purpose |
|---|---|
| `version` | State file format version (always 4 for current OpenTofu) |
| `terraform_version` | OpenTofu version that last modified this state |
| `serial` | Monotonically increasing integer; increments on every successful apply |
| `lineage` | Unique UUID for this state's lineage; prevents merging unrelated states |
| `outputs` | Current values of all root module output values |
| `resources` | Array of all managed resource instances |

### Resource Instance Structure

```json
{
  "mode": "managed",
  "type": "local_file",
  "name": "config",
  "provider": "provider[\"registry.terraform.io/hashicorp/local\"]",
  "instances": [
    {
      "schema_version": 0,
      "attributes": {
        "content": "Hello, OpenTofu!",
        "content_base64": null,
        "content_base64sha256": "abc123...",
        "content_md5": "def456...",
        "content_sha1": "ghi789...",
        "content_sha256": "jkl012...",
        "directory_permission": "0777",
        "file_permission": "0644",
        "filename": "/tmp/hello.txt",
        "id": "sha1-of-content"
      },
      "sensitive_attributes": [],
      "dependencies": [
        "random_pet.name"
      ]
    }
  ]
}
```

| Field | Meaning |
|---|---|
| `mode` | `"managed"` (resources) or `"data"` (data sources) |
| `schema_version` | Provider schema version at creation time; used for state migrations |
| `attributes` | All attribute values — both arguments you set AND computed values |
| `sensitive_attributes` | List of attribute paths marked sensitive |
| `dependencies` | Resource addresses this resource depends on |

> **Under the hood:** The `id` field is the resource's primary identifier in the real world. For `local_file`, it's a hash of the content. For cloud resources, it would be the resource's UUID or ARN. OpenTofu uses this ID to look up the resource during refresh.

### The `serial` Field

The serial number is critical for detecting concurrent modifications. Every successful `tofu apply` increments the serial by 1. If two clients have the same serial and both try to apply, the second one will fail with a "state conflict" error — OpenTofu detected that the state was modified since the second client read it.

### The `lineage` Field

The lineage UUID is generated once when a state is first created. It never changes. OpenTofu checks lineage when you run `tofu state push` to prevent accidentally overwriting the wrong state with a state from a different configuration.

↑ [Back to Table of Contents](#table-of-contents)

---

## The Plan/Refresh Cycle in Detail

### Phase 1: Refresh

OpenTofu calls the provider's `ReadResource` for every resource in state. The returned attributes update the in-memory state (but not the state file — that only happens after a successful apply).

```
State file: local_file.config.content = "Hello"
Provider read: local_file.config.content = "Hello, World!"  ← file was edited externally
In-memory state after refresh: content = "Hello, World!"
```

**Skipping refresh:**

```bash
# Skip the provider read — use state file as-is
tofu plan -refresh=false

# Only refresh state — don't plan changes, don't apply
tofu apply -refresh-only
```

### Phase 2: Diff

OpenTofu compares:
- **Desired state** from your HCL configuration
- **Actual state** from the refreshed state (provider read)

For each resource, the result is one of:
- **No change** — desired == actual
- **Update** — can be updated in-place
- **Replace** (`-/+`)  — a ForceNew attribute changed; must destroy + recreate
- **Create** — resource in HCL but not in state
- **Destroy** — resource in state but not in HCL

### Phase 3: Plan Output

The diff is formatted for humans:

```
Terraform will perform the following actions:

  # local_file.config must be replaced
  -/+ resource "local_file" "config" {
      ~ content              = "Hello" -> "Hello, World!" # forces replacement
        filename             = "/tmp/hello.txt"
      ~ id                   = "f572d396..." -> (known after apply)
    }

Plan: 1 to add, 0 to change, 1 to destroy.
```

### `tofu show -json` for Machine-Readable Plan

```bash
# Save plan to file
tofu plan -out=tfplan

# Convert to JSON for parsing
tofu show -json tfplan > plan.json

# Inspect with jq
cat plan.json | jq '.resource_changes[] | select(.change.actions[] | contains("create"))'
```

↑ [Back to Table of Contents](#table-of-contents)

---

## State Backends

A **backend** determines where state is stored and whether state locking is available.

### Local Backend (Default)

State is stored in `terraform.tfstate` in the working directory:

```hcl
terraform {
  backend "local" {
    path = "terraform.tfstate"  # optional; this is the default
  }
}
```

Local backend locking uses a `.tfstate.lock.info` file:

```json
{
  "ID": "a1b2c3d4-...",
  "Operation": "OperationTypeApply",
  "Info": "",
  "Who": "user@hostname",
  "Version": "1.8.0",
  "Created": "2026-03-02T10:00:00Z",
  "Path": "terraform.tfstate"
}
```

### Remote Backend Overview

Remote backends store state outside the working directory, enabling team collaboration:

| Backend | State Storage | Locking | Notes |
|---|---|---|---|
| `local` | Local file | File lock | Default; not for teams |
| `s3` | AWS S3 | DynamoDB | Most common remote backend |
| `gcs` | Google Cloud Storage | GCS locks | Native GCP option |
| `azurerm` | Azure Blob Storage | Blob leases | Native Azure option |
| `http` | Any HTTP endpoint | HTTP locking | Generic; any REST API |
| `kubernetes` | Kubernetes Secret | Lease | K8s-native |

### Configuring a Remote Backend

```hcl
terraform {
  backend "s3" {
    bucket         = "my-tofu-state"
    key            = "env/prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tofu-state-locks"
    encrypt        = true
  }
}
```

→ See [Module 09](../09-backends-and-remote-state/) for a full deep-dive on backends.

↑ [Back to Table of Contents](#table-of-contents)

---

## State Locking

State locking prevents concurrent `tofu apply` operations from corrupting state.

### How Locking Works

1. Before any operation that modifies state, OpenTofu acquires a lock
2. The lock is released after the operation completes (success or failure)
3. If another process holds the lock, OpenTofu waits and retries, then fails with:
   ```
   Error: Error acquiring the state lock
   Lock Info:
     ID:        a1b2c3d4-...
     Path:      terraform.tfstate
     Operation: OperationTypeApply
     Who:       user@hostname
     Created:   2026-03-02 10:00:00 +0000 UTC
   ```

### Force-Unlock

If a process crashed without releasing the lock, you can force-release it:

```bash
# Get the lock ID from the error message
tofu force-unlock a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

> **Warning:** Only force-unlock when you are **absolutely certain** no other process is currently applying. Force-unlocking while an apply is running can corrupt your state file.

### Lock Timeout

```bash
# Wait up to 5 minutes for a lock before failing
tofu apply -lock-timeout=5m

# Disable locking entirely (dangerous — only for debugging)
tofu apply -lock=false
```

↑ [Back to Table of Contents](#table-of-contents)

---

## State Operations

The `tofu state` subcommands give you surgical control over state.

### `tofu state list` — List All Resources

```bash
tofu state list
# local_file.config
# local_file.readme
# random_pet.name
# null_resource.setup

# Filter by resource type
tofu state list 'local_file.*'
```

### `tofu state show` — Inspect a Resource

```bash
tofu state show local_file.config
# # local_file.config:
# resource "local_file" "config" {
#     content              = "Hello"
#     filename             = "/tmp/config.txt"
#     id                   = "f572d396..."
# }
```

### `tofu state mv` — Rename / Move a Resource

Used to rename a resource in HCL without destroying and recreating it:

```bash
# Rename a resource (update HCL first, then run mv before apply)
tofu state mv local_file.config local_file.app_config

# Move a resource into a module
tofu state mv local_file.config module.files.local_file.config

# Move a resource out of a module
tofu state mv module.files.local_file.config local_file.config
```

> **Best practice:** For new code, use the `moved` block instead of `tofu state mv` — it is version-controlled and declarative. See [Module 12](../12-advanced-patterns/).

### `tofu state rm` — Remove from State (Without Destroying)

Removes a resource from state without deleting the real-world resource. Use when you want OpenTofu to "forget" a resource (e.g., to import it differently, or to hand management to another tool):

```bash
# Remove a specific resource
tofu state rm local_file.config

# Remove all instances of a for_each resource
tofu state rm 'local_file.configs["dev"]'
tofu state rm 'local_file.configs["staging"]'
```

### `tofu import` — Import an Existing Resource

Import a real-world resource that exists outside of OpenTofu's state:

```bash
# Imperative import (old style)
tofu import local_file.existing_config /tmp/existing.txt
```

The declarative `import` block (preferred, 1.5+) is covered in [Module 12](../12-advanced-patterns/).

### `tofu state pull` / `tofu state push`

```bash
# Download remote state to stdout (JSON)
tofu state pull > backup.tfstate

# Upload a local state file to the backend (dangerous)
tofu state push backup.tfstate
```

> **Danger:** `tofu state push` will overwrite remote state. Always create a backup first and verify the lineage and serial match expectations. Incorrectly pushing state can cause OpenTofu to lose track of resources.

↑ [Back to Table of Contents](#table-of-contents)

---

## State Drift

**Drift** occurs when the actual state of a resource in the real world differs from what OpenTofu has recorded in state.

### Common Causes of Drift

| Cause | Example |
|---|---|
| Manual changes | Editing a file that OpenTofu manages |
| Other automation tools | Another script modifies the same resource |
| Provider-side changes | Cloud provider modifies a resource attribute (auto-scaling, etc.) |
| Resource replacement | Resource is deleted and recreated outside OpenTofu |
| `ignore_changes` misuse | Changes are happening but OpenTofu is ignoring them |

### Detecting Drift

```bash
# Refresh-only plan: show what changed in the real world without planning any HCL changes
tofu plan -refresh-only
```

Output when drift is detected:
```
Note: Objects have changed outside of OpenTofu

OpenTofu detected the following changes made outside of OpenTofu since the
last "tofu apply":

  # local_file.config has been changed
  ~ resource "local_file" "config" {
      ~ content = "Hello" -> "Hello, World!"
        # (other attributes unchanged)
    }
```

### Remediating Drift

You have two choices when drift is detected:

**Option 1: Accept the drift (update state to match reality)**
```bash
# Apply the refresh-only plan — updates state to match current reality
tofu apply -refresh-only
```

**Option 2: Reconcile the drift (restore desired state)**
```bash
# Run a normal plan — OpenTofu will want to change the resource back to desired state
tofu plan
tofu apply   # this will overwrite the external change
```

Choose based on whether the external change was intentional and whether it should be preserved.

↑ [Back to Table of Contents](#table-of-contents)

---

## State Surgery

State surgery refers to direct manipulation of the state file — operations beyond normal plan/apply. Approach with extreme caution.

### Pre-Surgery Checklist

Before any state surgery operation:

```bash
# 1. Back up state
tofu state pull > state-backup-$(date +%Y%m%d-%H%M%S).tfstate

# 2. Verify backup
cat state-backup-*.tfstate | jq '.serial'

# 3. Ensure no one else is running tofu (communicate with team)

# 4. If remote backend: ensure the lock is not held
tofu state list   # will fail if locked
```

### Manual State File Editing

Only as a last resort (e.g., to fix a corrupted resource entry):

```bash
# Pull state
tofu state pull > edit-me.tfstate

# Edit the JSON carefully
vim edit-me.tfstate

# Increment the serial number manually (REQUIRED)
# If the current serial is 7, change it to 8

# Push back
tofu state push edit-me.tfstate

# Verify
tofu state list
tofu plan   # should show no unexpected changes
```

### State File Splitting

When a state file grows very large (hundreds of resources), you may want to split it into smaller roots. This is an advanced operation covered in [Module 12](../12-advanced-patterns/).

↑ [Back to Table of Contents](#table-of-contents)

---

## Exercises

### Exercise 1 — Easy: Inspect the State File

1. Use the Module 03 example configuration
2. Run `tofu init && tofu apply`
3. Run `tofu state list` — record all resource addresses
4. Run `tofu state show` on each resource — identify the `id`, `filename`, and any computed attributes
5. Open `terraform.tfstate` directly in a text editor and find:
   - The `serial` number
   - The `lineage` UUID
   - The `dependencies` array for a resource that depends on another
6. Run `tofu apply` again with no changes — confirm the serial does NOT increment (no changes = no new serial)
7. Make a small change to a variable and apply — confirm the serial increments

---

### Exercise 2 — Medium: `state mv` Rename

1. Use the Module 03 example (which has `local_file.env_config` resources)
2. Rename `local_file.env_config` to `local_file.environment_config` in `main.tf`
3. Run `tofu plan` — observe that OpenTofu plans to destroy `env_config` and create `environment_config`
4. Revert the HCL change
5. Run `tofu state mv 'local_file.env_config["dev"]' 'local_file.environment_config["dev"]'` — then update HCL for just that resource
6. Note: with `for_each`, you must move each instance individually
7. Instead, use the `moved` block approach (covered in Module 12) to move the entire `for_each` resource cleanly
8. Run `tofu plan` — confirm zero changes are planned
9. Explain in writing: when would you use `state mv` vs the `moved` block?

---

### Exercise 3 — Hard: Drift Detection and Remediation Runbook

1. Apply the Module 03 example
2. **Simulate drift**: manually edit one of the output files (e.g., change its content) outside of OpenTofu
3. Run `tofu plan -refresh-only` — confirm drift is detected and documented
4. Write a **drift remediation runbook** that covers:
   - How to identify which resources have drifted
   - Decision flowchart: accept drift vs reconcile drift
   - The exact commands to remediate each case
   - How to document the drift event for audit purposes
   - How to prevent the same drift from recurring (lifecycle rules, access controls, alerts)
5. Simulate the full remediation procedure both ways (accept and reconcile) and verify the outcome with `tofu plan` (should show no changes after remediation)

↑ [Back to Table of Contents](#table-of-contents)

---

## Further Reading

- [OpenTofu State Documentation](https://opentofu.org/docs/language/state/) — Official state reference
- [State File Format](https://opentofu.org/docs/internals/json-output-format/) — JSON output format reference
- [Backend Configuration](https://opentofu.org/docs/language/settings/backends/) — All backend types
- [tofu state subcommands](https://opentofu.org/docs/cli/commands/state/) — CLI reference for all state operations
- [Sensitive Data in State](https://opentofu.org/docs/language/state/sensitive-data/) — State and secrets management
- [Remote State Data Source](https://opentofu.org/docs/language/state/remote-state-data/) — Cross-configuration state sharing

↑ [Back to Table of Contents](#table-of-contents)

---

## Summary

| Concept | Key Takeaway |
|---|---|
| State purpose | Maps HCL addresses to real-world resource IDs and attributes |
| `serial` | Increments on every apply; used to detect concurrent modifications |
| `lineage` | Prevents accidental cross-configuration state merges |
| Refresh | Provider reads current reality; happens before every plan |
| `-refresh-only` | Detect drift without planning HCL changes |
| State locking | Prevents concurrent modifications; force-unlock with extreme caution |
| `state mv` | Rename/move resources without destroy + recreate |
| `state rm` | Remove from state without destroying real resource |
| Drift | Detect with `-refresh-only`; remediate by accepting or reconciling |
| State surgery | Always back up first; increment serial manually if editing JSON |

↑ [Back to Table of Contents](#table-of-contents)

---

## Next Module →

**[Module 06 — Modules](../06-modules/06-modules.md)**

Build reusable, versioned modules. Master module sources, composition patterns, and `for_each` on modules.


---

<sub>© 2026 UncleJS & Course OpenTofu contributors — licensed under [CC BY-NC-SA 4.0](../../LICENSE).<br>
You may share and adapt this material for non-commercial purposes with attribution.<br>
SPDX-License-Identifier: CC-BY-NC-SA-4.0</sub>