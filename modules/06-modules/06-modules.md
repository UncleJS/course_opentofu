# Module 06 — Modules

<!-- SPDX-License-Identifier: CC-BY-NC-SA-4.0 -->

[![Module](https://img.shields.io/badge/Module-06-blue)](.)
[![Difficulty](https://img.shields.io/badge/Difficulty-Intermediate-yellow)](.)
[![Time](https://img.shields.io/badge/Time-75%20min-lightgrey)](.)
[![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)

---

## Table of Contents

- [Overview](#overview)
- [Module Concepts](#module-concepts)
- [Module Sources](#module-sources)
- [Module Inputs and Outputs](#module-inputs-and-outputs)
- [Module Versioning](#module-versioning)
- [Module Composition Patterns](#module-composition-patterns)
- [`for_each` on Modules](#for_each-on-modules)
- [Module Development Best Practices](#module-development-best-practices)
- [Internals: The Module Graph](#internals-the-module-graph)
- [Exercises](#exercises)
- [Further Reading](#further-reading)
- [Summary](#summary)
- [Next Module →](#next-module-)

---

## Overview

Modules are the primary mechanism for code reuse, encapsulation, and organisation in OpenTofu. A well-designed module hides implementation complexity behind a clean, typed interface — making your infrastructure as composable as a library of functions.

This module covers:
- Root vs child modules and when to use each
- All module source types: local, Git, registry
- Module versioning and the lock file
- Composition patterns: flat, nested, wrapper, library
- Using `for_each` on module instances
- Best practices for module development

↑ [Back to Table of Contents](#table-of-contents)

---

## Module Concepts

### Root Module vs Child Modules

Every OpenTofu configuration has a **root module** — the directory where you run `tofu init`. A root module can call **child modules**, which are reusable units of configuration.

```
root module (where you run tofu apply)
│
├── module "app_files" {
│     source = "./modules/file-generator"  ← child module
│     ...
│   }
│
└── module "reports" {
      source = "./modules/file-generator"  ← same module, different instance
      ...
    }
```

### What a Module Is

A module is simply **a directory of `.tf` files**. There is nothing special about the directory — what makes it a module is how it is called.

### When to Use Modules

Use modules when:
- The same pattern of resources is repeated across environments or projects
- You want to enforce consistent configuration (e.g., standard tagging, naming)
- A group of resources forms a logical unit with a clear interface
- You want to hide complexity behind a simple API

**When NOT to use modules:**
- Single-use configurations that won't be repeated
- When the abstraction adds more complexity than it removes
- To satisfy a DRY reflex when the duplication is minor

> A good rule of thumb: if you find yourself copy-pasting 5+ resources across multiple directories, it is time to create a module.

↑ [Back to Table of Contents](#table-of-contents)

---

## Module Sources

The `source` argument tells OpenTofu where to find the module.

### Local Paths

```hcl
module "files" {
  source = "./modules/file-generator"    # relative to root module
}

module "shared" {
  source = "../shared-modules/logger"    # relative, going up
}
```

Local modules are resolved relative to the calling module's directory. They are **not versioned** — changes are always picked up on the next `tofu init`.

### Git Sources

```hcl
# HTTPS with tag ref
module "files" {
  source = "git::https://github.com/myorg/tofu-modules.git//file-generator?ref=v1.2.0"
}

# SSH with branch ref
module "files" {
  source = "git::ssh://git@github.com/myorg/tofu-modules.git//file-generator?ref=main"
}

# GitHub shorthand
module "files" {
  source = "github.com/myorg/tofu-modules//file-generator?ref=v1.2.0"
}

# Specific commit hash (most stable)
module "files" {
  source = "git::https://github.com/myorg/tofu-modules.git//file-generator?ref=abc1234"
}
```

The `//` separates the repository URL from the subdirectory within the repo.

### Registry Sources

```hcl
# Public registry (registry.opentofu.org by default)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
}

# Private registry
module "internal" {
  source  = "app.terraform.io/myorg/internal-module/platform"
  version = "= 2.1.0"
}
```

Registry sources are the only source type that supports the `version` argument for pinning.

↑ [Back to Table of Contents](#table-of-contents)

---

## Module Inputs and Outputs

### Passing Inputs to a Module

```hcl
# Root module
module "app_files" {
  source = "./modules/file-generator"

  # These become the values of `var.*` inside the module
  output_dir  = "output/app"
  file_prefix = "app"
  files = {
    config = "app configuration content"
    readme = "app readme content"
  }
}
```

### Accessing Module Outputs

```hcl
# Access a module's output value
output "app_config_path" {
  value = module.app_files.config_path
}

# Use a module output as input to another resource
resource "local_file" "master_index" {
  filename = "output/index.txt"
  content  = join("\n", module.app_files.all_file_paths)
}
```

### Module Output Passthrough

A common pattern: the root module exposes child module outputs directly:

```hcl
output "all_paths" {
  description = "All file paths from the file generator module"
  value       = module.app_files.all_file_paths
}
```

↑ [Back to Table of Contents](#table-of-contents)

---

## Module Versioning

### `version` Argument (Registry Modules Only)

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"   # any 5.x release
}
```

### Lock File and Module Hashes

When you run `tofu init`, module versions are recorded in `.terraform.lock.hcl` alongside provider versions. For registry modules, checksums are verified on every init.

### Upgrading Modules

```bash
# Upgrade all modules to the latest version within constraints
tofu init -upgrade

# Check what will change before upgrading
# (review the lock file diff in git after -upgrade)
```

### Safe Upgrade Process

1. Run `tofu init -upgrade` on a branch
2. Review `.terraform.lock.hcl` changes in git diff
3. Run `tofu plan` — look for unexpected resource changes
4. Test in a non-production workspace
5. Merge to main and apply to production

↑ [Back to Table of Contents](#table-of-contents)

---

## Module Composition Patterns

### Flat Module Structure (Recommended for Most Cases)

All module calls are at the root level. Simple, easy to trace:

```
root/
├── main.tf          # calls multiple modules directly
├── modules/
│   ├── files/
│   └── reports/
```

```hcl
# main.tf
module "app_files" {
  source = "./modules/files"
  ...
}

module "report_files" {
  source = "./modules/reports"
  ...
}
```

### Nested Module Structure

A module calls other modules internally. Useful for complex abstractions, but harder to trace:

```
modules/
└── environment/     ← calls file-set internally
    └── main.tf: module "files" { source = "../file-set" }
```

### Wrapper Module Pattern

A thin wrapper around an existing module that enforces organisational standards:

```hcl
# modules/standard-file/main.tf
# Wraps the file-generator module and enforces naming conventions

module "file_gen" {
  source = "../file-generator"

  # Force all files through standard naming
  file_prefix = "org-${var.team}-${var.environment}"
  output_dir  = var.output_dir
  files       = var.files
}

# Enforce mandatory metadata tag in every generated file
resource "local_file" "metadata" {
  filename = "${var.output_dir}/.metadata"
  content  = jsonencode({
    team        = var.team
    environment = var.environment
    managed_by  = "opentofu"
  })
}
```

### Library Module vs App Module

| Type | Purpose | Characteristics |
|---|---|---|
| **Library module** | Reusable across many projects | Highly parameterised, no assumptions about context |
| **App module** | Specific to one application | Can have opinionated defaults, less general |

↑ [Back to Table of Contents](#table-of-contents)

---

## `for_each` on Modules

You can instantiate a module multiple times using `for_each`:

```hcl
variable "environments" {
  type = map(object({
    replica_count = number
    debug         = bool
  }))
  default = {
    dev  = { replica_count = 1, debug = true }
    prod = { replica_count = 3, debug = false }
  }
}

module "env_files" {
  for_each = var.environments
  source   = "./modules/file-generator"

  environment   = each.key
  replica_count = each.value.replica_count
  debug_enabled = each.value.debug
  output_dir    = "output/${each.key}"
}

# Access outputs from each module instance
output "all_config_paths" {
  value = {
    for env, mod in module.env_files : env => mod.config_path
  }
}
```

Module instance addresses: `module.env_files["dev"]`, `module.env_files["prod"]`

### Deletion Behaviour with `for_each` on Modules

When you remove a key from the `for_each` map:
- Only that module instance is destroyed
- Other instances are unaffected
- Resources inside the module are destroyed in reverse dependency order

This is why `for_each` is almost always preferred over `count` for module instantiation.

↑ [Back to Table of Contents](#table-of-contents)

---

## Module Development Best Practices

### Standard File Layout

```
modules/file-generator/
├── main.tf          # Resources
├── variables.tf     # Input variable declarations
├── outputs.tf       # Output value declarations
├── versions.tf      # required_providers, required_version
└── README.md        # Usage documentation (ideally auto-generated)
```

### Always Declare `required_providers`

Even child modules should declare their provider requirements:

```hcl
# modules/file-generator/versions.tf
terraform {
  required_version = ">= 1.6"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}
```

### Add Input Validation

```hcl
# modules/file-generator/variables.tf
variable "output_dir" {
  type        = string
  description = "Directory for output files"

  validation {
    condition     = length(var.output_dir) > 0
    error_message = "output_dir must not be empty."
  }
}
```

### Avoid Hard-Coded Providers

Never configure a provider inside a child module. Let the root module (or caller) configure providers:

```hcl
# WRONG — hard-coded provider in child module
provider "local" {
  # this makes the module non-reusable
}

# RIGHT — no provider block in child module; provider is inherited
```

### Don't Use `depends_on` on Modules

The `depends_on` argument on a `module` block forces **all** resources in the module to wait, even those that don't need to. Prefer explicit dependencies inside the module.

↑ [Back to Table of Contents](#table-of-contents)

---

## Internals: The Module Graph

### Module Instance Expansion

When OpenTofu builds the dependency graph, it expands module instances into individual resources. A module called with `for_each = { dev = ..., prod = ... }` that contains 3 resources will result in 6 resource nodes in the graph.

> **Under the hood:** Module expansion happens before the graph walk. OpenTofu first builds a "configuration graph" (abstract), then expands it into the "plan graph" (concrete) by resolving `count`, `for_each`, and module instances. This is why unknown values in `for_each` are not allowed — the graph cannot be built without knowing the keys.

### Provider Inheritance

Resources inside a module inherit the provider configuration from their caller unless explicitly overridden. This means:

```hcl
# Root: configures "local" provider
provider "local" {}

# Child module: automatically uses the root's "local" provider
# No provider block needed in the module
```

For aliased providers, the root must explicitly pass them:

```hcl
module "files" {
  source = "./modules/files"
  providers = {
    local = local.alternate  # pass the aliased provider
  }
}
```

↑ [Back to Table of Contents](#table-of-contents)

---

## Exercises

### Exercise 1 — Easy: Extract to a Child Module

Take the Module 04 app deployment example and extract the file-creation logic into a reusable child module:

1. Create `modules/06-modules/examples/modules/file-set/` with `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`
2. The module should accept: `output_dir (string)`, `files (map(string))`, `file_permission (string, default "0644")`
3. The module should output: `file_paths (map(string))` mapping filename key → absolute path
4. Call the module from a root `main.tf`
5. Verify the output matches the original example

---

### Exercise 2 — Medium: `for_each` Module Instantiation

Using the `file-set` module from Exercise 1:

1. Define a `map(object(...))` variable `environments` with 3 environments (dev/staging/prod), each having a `files` map and a `subdir` string
2. Use `for_each` to instantiate `file-set` once per environment, writing to `output/<env>/`
3. Output a combined `all_paths` map of `"<env>/<key>"` → absolute path (hint: use `merge()` and `for` expressions)
4. Delete one environment from the map and apply — confirm only its files are removed

---

### Exercise 3 — Hard: Two-Layer Module Composition

Build a two-layer module hierarchy:

1. **Layer 1** (`modules/file-set/`): Creates files from a `map(string)` — already built in Exercise 1
2. **Layer 2** (`modules/environment/`): Calls `file-set` internally and also creates an `environment-manifest.json` that lists all files, env name, and a timestamp
3. **Root module**: Calls `environment` with `for_each` for dev/staging/prod
4. Root output: `environment_manifests` — map of env name → manifest file path
5. Add a `precondition` to the `environment` module's output that verifies the manifest file exists
6. Test the precondition by temporarily forcing a bad filename and observing the error

↑ [Back to Table of Contents](#table-of-contents)

---

## Further Reading

- [OpenTofu Modules Documentation](https://opentofu.org/docs/language/modules/) — Complete module reference
- [Module Sources](https://opentofu.org/docs/language/modules/sources/) — All source types with examples
- [Module Composition](https://opentofu.org/docs/language/modules/develop/composition/) — Patterns and anti-patterns
- [terraform-docs](https://terraform-docs.io/) — Auto-generate module README from variables/outputs
- [Module Registry — Best Practices](https://registry.terraform.io/browse/modules) — Browse well-structured real-world modules
- [Calling Modules with for_each](https://opentofu.org/docs/language/meta-arguments/module-providers/) — Provider passing and for_each on modules

↑ [Back to Table of Contents](#table-of-contents)

---

## Summary

| Concept | Key Takeaway |
|---|---|
| Module | A directory of `.tf` files with a variable/output interface |
| Source | Local path, Git URL, or registry address; only registry supports `version` |
| Inputs/outputs | The module's public API — type and validate them carefully |
| Flat structure | Preferred over deeply nested modules for maintainability |
| `for_each` on modules | Instantiate multiple copies safely with key-based addressing |
| Provider inheritance | Modules inherit providers from caller; pass aliases explicitly |
| Avoid hard-coding | No provider blocks, no hardcoded paths inside child modules |

↑ [Back to Table of Contents](#table-of-contents)

---

## Next Module →

**[Module 07 — Workspaces](../07-workspaces/07-workspaces.md)**

Use workspaces to manage multiple environments from a single configuration. Understand their limitations and the alternatives.


---

<sub>© 2026 UncleJS & Course OpenTofu contributors — licensed under [CC BY-NC-SA 4.0](../../LICENSE).<br>
You may share and adapt this material for non-commercial purposes with attribution.<br>
SPDX-License-Identifier: CC-BY-NC-SA-4.0</sub>