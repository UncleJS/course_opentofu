# Module 07 — Workspaces

<!-- SPDX-License-Identifier: CC-BY-NC-SA-4.0 -->

[![Module](https://img.shields.io/badge/Module-07-blue)](.)
[![Difficulty](https://img.shields.io/badge/Difficulty-Intermediate-yellow)](.)
[![Time](https://img.shields.io/badge/Time-45%20min-lightgrey)](.)
[![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)

---

## Table of Contents

- [Overview](#overview)
- [What Workspaces Are (and Aren't)](#what-workspaces-are-and-arent)
- [Workspace CLI Commands](#workspace-cli-commands)
- [Per-Workspace Configuration Patterns](#per-workspace-configuration-patterns)
- [Workspace Limitations and Anti-Patterns](#workspace-limitations-and-anti-patterns)
- [Alternatives to Workspaces](#alternatives-to-workspaces)
- [Exercises](#exercises)
- [Further Reading](#further-reading)
- [Summary](#summary)
- [Next Module →](#next-module-)

---

## Overview

Workspaces allow a single OpenTofu configuration to manage multiple independent state files. They are most commonly used to represent environments (dev, staging, prod) within a single codebase.

This module covers the full workspace feature — including its considerable limitations — and compares it to alternative approaches so you can make an informed architectural decision.

↑ [Back to Table of Contents](#table-of-contents)

---

## What Workspaces Are (and Aren't)

### What a Workspace Is

A workspace is a **named state slice** within a backend. Each workspace has:
- Its own state file
- Its own independent resource lifecycle
- Access to the same HCL configuration

The `default` workspace always exists and is used when no workspace is explicitly selected.

```bash
# When no workspace is selected, you are in "default"
tofu workspace show
# default
```

### `terraform.workspace` Interpolation

Inside your HCL, you can read the current workspace name:

```hcl
locals {
  environment = terraform.workspace   # "dev", "staging", "prod", or "default"
}

resource "local_file" "config" {
  filename = "output/${terraform.workspace}/config.txt"
  content  = "Running in workspace: ${terraform.workspace}"
}
```

### What a Workspace Is NOT

A workspace is **not**:
- A security boundary (all workspaces share the same provider credentials)
- A substitute for separate configurations with different architectures
- A way to isolate provider configurations or IAM roles
- A replacement for separate root modules in complex organisations

↑ [Back to Table of Contents](#table-of-contents)

---

## Workspace CLI Commands

```bash
# List all workspaces (* marks current)
tofu workspace list
# * default
#   dev
#   staging
#   prod

# Create a new workspace (and switch to it)
tofu workspace new dev

# Switch to an existing workspace
tofu workspace select staging

# Show the current workspace name
tofu workspace show

# Delete a workspace (must be empty — no resources in state)
tofu workspace select default
tofu workspace delete dev
```

### Workspace State File Locations

With the local backend, each workspace gets its own state file:

```
terraform.tfstate            ← "default" workspace
terraform.tfstate.d/
├── dev/
│   └── terraform.tfstate   ← "dev" workspace
├── staging/
│   └── terraform.tfstate   ← "staging" workspace
└── prod/
    └── terraform.tfstate   ← "prod" workspace
```

With the S3 backend:
```
s3://my-bucket/env:/dev/terraform.tfstate
s3://my-bucket/env:/staging/terraform.tfstate
s3://my-bucket/env:/prod/terraform.tfstate
```

↑ [Back to Table of Contents](#table-of-contents)

---

## Per-Workspace Configuration Patterns

### Pattern 1: Direct `terraform.workspace` Interpolation

```hcl
locals {
  is_prod  = terraform.workspace == "prod"
  replicas = local.is_prod ? 3 : 1
}

resource "local_file" "config" {
  filename = "output/${terraform.workspace}/app.conf"
  content  = "replicas = ${local.replicas}"
}
```

### Pattern 2: `lookup()` Map Pattern

Define a map of workspace-specific values and look up the current workspace:

```hcl
locals {
  env_config = {
    dev = {
      replicas    = 1
      log_level   = "debug"
      allowed_ips = ["0.0.0.0/0"]
    }
    staging = {
      replicas    = 2
      log_level   = "info"
      allowed_ips = ["10.0.0.0/8"]
    }
    prod = {
      replicas    = 5
      log_level   = "warn"
      allowed_ips = ["10.0.0.0/8", "172.16.0.0/12"]
    }
  }

  # Fallback to "dev" config for unknown workspaces (e.g., "default")
  config = lookup(local.env_config, terraform.workspace, local.env_config["dev"])
}

resource "local_file" "app_config" {
  filename = "output/${terraform.workspace}/config.json"
  content  = jsonencode(local.config)
}
```

### Pattern 3: Per-Workspace Variable Files

Keep workspace-specific variable overrides in separate files:

```bash
# Run plan with workspace-specific variables
tofu workspace select prod
tofu plan -var-file="envs/prod.tfvars"
```

```hcl
# envs/dev.tfvars
replica_count = 1
log_level     = "debug"

# envs/prod.tfvars
replica_count = 5
log_level     = "warn"
```

This pattern works well but requires the caller to remember to pass the right `-var-file`.

↑ [Back to Table of Contents](#table-of-contents)

---

## Workspace Limitations and Anti-Patterns

### Limitation 1: Shared Provider Configuration

All workspaces share the same provider configuration. You cannot have different AWS accounts, different regions, or different credentials per workspace without additional tooling.

```hcl
# This provider applies to ALL workspaces equally
provider "aws" {
  region = "us-east-1"
  # No way to use different credentials per workspace
}
```

### Limitation 2: State Blast Radius

All workspaces are in the same backend configuration. An accidental `tofu destroy` in the wrong workspace destroys production resources. There is no inherent isolation.

### Limitation 3: Divergent Architecture Not Supported

If your dev and prod environments have fundamentally different architectures (e.g., dev uses SQLite, prod uses PostgreSQL), workspaces are not suitable. Use separate root modules.

### Common Anti-Patterns

```hcl
# ANTI-PATTERN: Conditional provider alias based on workspace
provider "aws" {
  alias  = "prod_account"
  # Workspaces can't hold separate credentials — this doesn't work as expected
}

# ANTI-PATTERN: Using workspace name as a namespace for everything
# This leads to workspace-aware logic spread throughout the codebase,
# making it hard to reason about any single environment.
resource "local_file" "every_resource" {
  filename = "${terraform.workspace}/every/single/resource.txt"
  # When workspace logic is everywhere, deleting a workspace
  # becomes impossible without side effects
}
```

↑ [Back to Table of Contents](#table-of-contents)

---

## Alternatives to Workspaces

### Directory-Per-Environment (Recommended for Most Teams)

Each environment gets its own directory with its own state:

```
infra/
├── dev/
│   ├── main.tf       # calls shared modules
│   ├── variables.tf
│   └── terraform.tfvars
├── staging/
│   └── ...
└── prod/
    └── ...
modules/
└── app/
    └── ...
```

**Advantages:**
- Complete isolation between environments
- Different architectures per environment
- Separate credentials per environment
- No shared state blast radius

**Disadvantages:**
- More code duplication (mitigated by modules)
- Harder to apply changes across all environments simultaneously

### Terragrunt (DRY Directory-Per-Environment)

Terragrunt is a thin wrapper around OpenTofu that reduces duplication in the directory-per-environment pattern:

```hcl
# terragrunt.hcl
terraform {
  source = "git::https://github.com/myorg/modules.git//app?ref=v1.0"
}

inputs = {
  environment = "prod"
  replicas    = 5
}
```

### OpenTofu Stacks (Future)

The OpenTofu team is working on a native "Stacks" feature (planned for 2.0) that provides true environment isolation without the limitations of workspaces.

↑ [Back to Table of Contents](#table-of-contents)

---

## Exercises

### Exercise 1 — Easy: Create and Inspect Workspaces

1. In the Module 03 example directory, create workspaces: `dev`, `staging`, `prod`
2. Switch to `dev` and run `tofu apply`
3. Switch to `prod` and run `tofu apply`
4. List the state files created in `terraform.tfstate.d/`
5. Run `tofu workspace list` from each workspace and observe the `*` marker
6. Run `tofu state list` in each workspace — confirm they are separate states

---

### Exercise 2 — Medium: Workspace-Aware Configuration

Build a workspace-aware configuration that:

1. Uses the `lookup()` map pattern to vary the number of files created per workspace
2. Creates files in `output/<workspace>/` directories
3. In the `prod` workspace, enforces a `prevent_destroy = true` lifecycle on the files
4. Outputs the current workspace, replica count, and list of created files
5. Apply in all three workspaces and verify the differences
6. Try to `tofu destroy` in the `prod` workspace — observe the error from `prevent_destroy`

---

### Exercise 3 — Hard: Workspace vs Directory Comparison

Build the same configuration using two different approaches and document the tradeoffs:

**Approach A:** Single configuration with workspaces for dev/staging/prod
**Approach B:** Three separate directories (`envs/dev/`, `envs/staging/`, `envs/prod/`) each calling a shared module

For each approach:
1. Implement the full configuration (files per environment, environment-specific content)
2. Measure: lines of HCL in each approach
3. Simulate: how would you apply a config change to all three environments?
4. Simulate: how would you give different team members access to only their environment?
5. Write a one-page decision document explaining when to choose each approach and why

↑ [Back to Table of Contents](#table-of-contents)

---

## Further Reading

- [OpenTofu Workspaces Documentation](https://opentofu.org/docs/language/state/workspaces/) — Official workspace reference
- [When to Use Workspaces](https://opentofu.org/docs/cli/workspaces/) — CLI workspace commands
- [Terragrunt](https://terragrunt.gruntwork.io/) — DRY wrapper for directory-per-environment
- [The Workspace Gotcha](https://blog.gruntwork.io/how-to-manage-terraform-state-28f5697e68fa) — Blog post on workspace limitations
- [OpenTofu Stacks RFC](https://github.com/opentofu/opentofu/issues/1197) — Future native stacks feature discussion

↑ [Back to Table of Contents](#table-of-contents)

---

## Summary

| Concept | Key Takeaway |
|---|---|
| Workspace | Named state slice; same config, separate state |
| `terraform.workspace` | Read current workspace name in HCL |
| `lookup()` pattern | Map workspace names to per-environment config objects |
| Limitations | Shared credentials, state blast radius, no architecture divergence |
| Directory-per-env | Better isolation; use modules to reduce duplication |
| Terragrunt | Reduces directory-per-env boilerplate |

↑ [Back to Table of Contents](#table-of-contents)

---

## Next Module →

**[Module 08 — Functions & Expressions](../08-functions-and-expressions/08-functions-and-expressions.md)**

Master every built-in function, `for` expressions, `dynamic` blocks, `templatefile()`, and defensive `try()`/`can()` patterns.


---

<sub>© 2026 UncleJS & Course OpenTofu contributors — licensed under [CC BY-NC-SA 4.0](../../LICENSE).<br>
You may share and adapt this material for non-commercial purposes with attribution.<br>
SPDX-License-Identifier: CC-BY-NC-SA-4.0</sub>