# Module 04 — Variables & Outputs

<!-- SPDX-License-Identifier: CC-BY-NC-SA-4.0 -->

[![Module](https://img.shields.io/badge/Module-04-blue)](.)
[![Difficulty](https://img.shields.io/badge/Difficulty-Beginner-green)](.)
[![Time](https://img.shields.io/badge/Time-60%20min-lightgrey)](.)
[![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)

---

## Table of Contents

- [Overview](#overview)
- [Input Variables](#input-variables)
- [Variable Value Precedence](#variable-value-precedence)
- [Output Values](#output-values)
- [Local Values](#local-values)
- [Sensitive Values](#sensitive-values)
- [Complex Variable Patterns](#complex-variable-patterns)
- [Exercises](#exercises)
- [Further Reading](#further-reading)
- [Summary](#summary)
- [Next Module →](#next-module-)

---

## Overview

Variables and outputs are the public interface of any OpenTofu module. Input variables accept values from the caller; output values expose results to the caller or terminal. Local values reduce repetition within a module.

Getting variables right is critical: well-typed, validated variables prevent entire categories of runtime errors and make modules self-documenting.

This module covers:
- All HCL type constraints
- Every variable argument: `default`, `description`, `validation`, `sensitive`, `nullable`
- The complete variable resolution order
- Output arguments including `precondition`
- Local values and when to use them
- Sensitive value propagation and state implications
- Production-grade complex variable patterns with `optional()` and `object()`

↑ [Back to Table of Contents](#table-of-contents)

---

## Input Variables

Input variables parameterise your configuration. They are declared with `variable` blocks and referenced as `var.<name>`.

### Basic Variable Declaration

```hcl
# variables.tf
variable "environment" {
  type        = string
  description = "The deployment environment (dev, staging, prod)"
  default     = "dev"
}

variable "instance_count" {
  type        = number
  description = "Number of instances to create"
  default     = 1
}

variable "enable_logging" {
  type        = bool
  description = "Whether to enable detailed logging"
  default     = false
}
```

### All Type Constraints

```hcl
# Primitive types
variable "name"    { type = string }
variable "count"   { type = number }
variable "enabled" { type = bool   }

# Collection types (elements must be the same type)
variable "names"  { type = list(string)        }
variable "tags"   { type = map(string)         }
variable "ids"    { type = set(string)         }

# Structural types (elements can be different types)
variable "server" {
  type = object({
    name    = string
    port    = number
    enabled = bool
    tags    = map(string)
  })
}

variable "coordinates" {
  type = tuple([string, number, bool])
  # Fixed-length, ordered, mixed types: ["hostname", 8080, true]
}

# any — accepts any type (avoid in validated code; use for generic modules)
variable "config" { type = any }
```

### `nullable` Argument

Controls whether the variable can be set to `null`:

```hcl
variable "optional_name" {
  type     = string
  nullable = true    # default is true for most types
  default  = null    # explicitly null default
}

variable "required_name" {
  type     = string
  nullable = false   # null is rejected even if passed explicitly
}
```

### Validation Rules

Add `validation` blocks to enforce invariants on variable values:

```hcl
variable "environment" {
  type        = string
  description = "Deployment environment"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "port" {
  type        = number
  description = "Application port"

  validation {
    condition     = var.port >= 1024 && var.port <= 65535
    error_message = "Port must be between 1024 and 65535 (inclusive)."
  }
}

variable "name" {
  type        = string
  description = "Resource name"

  validation {
    condition     = length(var.name) >= 3 && length(var.name) <= 63
    error_message = "Name must be between 3 and 63 characters."
  }

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.name))
    error_message = "Name must start with a letter, end with a letter or digit, and contain only lowercase letters, digits, and hyphens."
  }
}
```

Multiple `validation` blocks are evaluated independently — all must pass. The `condition` expression must evaluate to `true` for the validation to pass. The `error_message` must be a plain string (no interpolation from other variables).

### `optional()` in Object Types

The `optional()` function in type constraints allows certain object attributes to be omitted, with an optional default value:

```hcl
variable "server_config" {
  type = object({
    name    = string
    port    = optional(number, 8080)      # defaults to 8080 if omitted
    enabled = optional(bool, true)         # defaults to true if omitted
    tags    = optional(map(string), {})    # defaults to empty map if omitted
    tls = optional(object({
      cert_path = string
      key_path  = string
    }))   # defaults to null if omitted
  })
  default = {
    name = "default-server"
  }
}
```

With `optional()`, callers only need to provide `name`; everything else has a sensible default.

↑ [Back to Table of Contents](#table-of-contents)

---

## Variable Value Precedence

OpenTofu resolves variable values from multiple sources. When the same variable is set in multiple places, this is the **resolution order** (later sources override earlier ones):

| Priority | Source | Example |
|---|---|---|
| 1 (lowest) | Default value in `variable` block | `default = "dev"` |
| 2 | `terraform.tfvars` file (auto-loaded) | `environment = "staging"` |
| 3 | `*.auto.tfvars` files (auto-loaded, alphabetical) | `prod.auto.tfvars` |
| 4 | `-var-file` flag | `tofu apply -var-file=prod.tfvars` |
| 5 | `TF_VAR_<name>` environment variables | `TF_VAR_environment=prod` |
| 6 (highest) | `-var` flag | `tofu apply -var="environment=prod"` |

### `.tfvars` Files

```hcl
# terraform.tfvars — auto-loaded
environment    = "staging"
instance_count = 3
enable_logging = true
```

```hcl
# prod.auto.tfvars — auto-loaded (*.auto.tfvars)
environment    = "prod"
instance_count = 10
```

```hcl
# custom.tfvars — only loaded with -var-file=custom.tfvars
instance_count = 5
```

### Environment Variables

```bash
# Set a string variable
export TF_VAR_environment="prod"

# Set a complex variable (JSON syntax)
export TF_VAR_server_config='{"name":"web","port":443}'

# Apply with env var
tofu apply
```

### Variable Files Format

`.tfvars` files support both HCL and JSON:

```json
// prod.tfvars.json
{
  "environment": "prod",
  "instance_count": 10,
  "tags": {
    "team": "platform",
    "cost-centre": "engineering"
  }
}
```

↑ [Back to Table of Contents](#table-of-contents)

---

## Output Values

Output values expose information from a module after apply. In the root module, they are printed to the terminal. In child modules, they are accessible to the calling module.

### Basic Output

```hcl
# outputs.tf
output "file_path" {
  description = "The path of the created file"
  value       = local_file.config.filename
}

output "all_file_paths" {
  description = "Paths of all created files"
  value       = { for k, v in local_file.configs : k => v.filename }
}
```

### `sensitive` Output

```hcl
output "api_key" {
  description = "The generated API key (sensitive)"
  value       = random_string.api_key.result
  sensitive   = true
  # Value is redacted in terminal output:
  # api_key = <sensitive>
  # But IS stored in state in plaintext
}
```

### `depends_on` for Outputs

Rarely needed, but useful when an output's value is correct but the resource it describes
has a side effect that must complete first:

```hcl
output "app_url" {
  value      = "http://localhost:${var.port}"
  depends_on = [null_resource.start_app]
}
```

### `precondition` for Outputs

Validate that a precondition is met before the output is used:

```hcl
output "config_path" {
  value = local_file.config.filename

  precondition {
    condition     = fileexists(local_file.config.filename)
    error_message = "Config file was not created at the expected path."
  }
}
```

### Accessing Outputs

```bash
# Print all outputs
tofu output

# Print a specific output (raw value, no quotes)
tofu output -raw file_path

# Print outputs as JSON
tofu output -json

# Print a specific output as JSON
tofu output -json all_file_paths
```

↑ [Back to Table of Contents](#table-of-contents)

---

## Local Values

Local values (`locals`) are named expressions scoped to the current module. Unlike variables, they cannot be overridden from outside the module.

### When to Use Locals

Use locals when:
- An expression appears more than once
- A complex expression benefits from a readable name
- You want to compute a value from multiple variables

```hcl
locals {
  # Combine multiple variables into a derived value
  app_name = "${var.project}-${var.environment}"

  # Avoid repeating a long expression
  common_tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "opentofu"
    created_at  = formatdate("YYYY-MM-DD", timestamp())
  }

  # Conditional logic
  is_production = var.environment == "prod"
  replica_count = local.is_production ? 3 : 1

  # Complex transformations
  instance_names = [
    for i in range(local.replica_count) :
    "${local.app_name}-${i}"
  ]
}

resource "local_file" "config" {
  filename = "output/${local.app_name}/config.txt"
  content  = "replicas: ${local.replica_count}"
}
```

### Locals Referencing Other Locals

Locals can reference other locals. OpenTofu resolves them in dependency order:

```hcl
locals {
  base_name    = "${var.project}-${var.environment}"
  full_name    = "${local.base_name}-${var.region}"
  config_path  = "configs/${local.full_name}"
}
```

Circular references between locals are not allowed and will cause an error.

↑ [Back to Table of Contents](#table-of-contents)

---

## Sensitive Values

Handling sensitive data (passwords, API keys, tokens) correctly is critical.

### Marking Variables as Sensitive

```hcl
variable "db_password" {
  type        = string
  description = "Database password"
  sensitive   = true
}
```

When a variable is sensitive:
- Its value is **redacted** from plan/apply CLI output: `(sensitive value)`
- The redaction **propagates** — any resource attribute or output that uses the sensitive value is also redacted
- The value is **still stored in plaintext** in the state file

### Sensitive Propagation

```hcl
variable "api_key" {
  type      = string
  sensitive = true
}

locals {
  # This local is automatically sensitive because it references a sensitive variable
  auth_header = "Bearer ${var.api_key}"
}

resource "local_file" "auth_config" {
  filename = "/tmp/auth.txt"
  content  = local.auth_header   # content attribute is automatically sensitive
}

output "config_preview" {
  value     = local_file.auth_config.content
  sensitive = true   # must explicitly mark output as sensitive
}
```

### The State File Warning

**The most important caveat about sensitive values:**

Sensitive marking in OpenTofu only affects **CLI output redaction**. The actual value is stored in plaintext in `terraform.tfstate`:

```json
{
  "resources": [{
    "instances": [{
      "attributes": {
        "content": "Bearer sk-actual-secret-api-key-here"
      }
    }]
  }]
}
```

**Mitigations:**
- Use remote state backends with encryption at rest (Module 09)
- Restrict access to the state file
- Use OpenTofu 1.7+ state encryption feature
- Consider using `local_sensitive_file` for files with secret content
- Never commit state files to Git

### Secrets Management Patterns

For production use, avoid putting secrets in variables entirely. Instead:

1. **Environment variables at runtime** — inject secrets as `TF_VAR_*` from a secrets manager in CI/CD
2. **Vault provider** — fetch secrets directly from HashiCorp Vault or OpenBao
3. **AWS SSM / Secrets Manager data sources** — read secrets from cloud secret stores
4. **`local_sensitive_file`** — ensure file permissions restrict access to the secret file

↑ [Back to Table of Contents](#table-of-contents)

---

## Complex Variable Patterns

### `map(object(...))` for Per-Environment Configuration

A powerful pattern for multi-environment configs:

```hcl
variable "environments" {
  type = map(object({
    replica_count  = number
    debug_enabled  = bool
    allowed_ips    = list(string)
    extra_config   = optional(map(string), {})
  }))

  default = {
    dev = {
      replica_count = 1
      debug_enabled = true
      allowed_ips   = ["0.0.0.0/0"]
    }
    staging = {
      replica_count = 2
      debug_enabled = false
      allowed_ips   = ["10.0.0.0/8"]
    }
    prod = {
      replica_count = 5
      debug_enabled = false
      allowed_ips   = ["10.0.0.0/8", "172.16.0.0/12"]
    }
  }

  validation {
    condition     = alltrue([for env, cfg in var.environments : cfg.replica_count > 0])
    error_message = "All environments must have at least one replica."
  }
}

resource "local_file" "env_configs" {
  for_each = var.environments

  filename = "output/${each.key}-config.json"
  content  = jsonencode({
    environment   = each.key
    replicas      = each.value.replica_count
    debug         = each.value.debug_enabled
    allowed_ips   = each.value.allowed_ips
    extra         = each.value.extra_config
  })
}
```

### Merging Maps for Default Override

```hcl
variable "custom_tags" {
  type    = map(string)
  default = {}
}

locals {
  default_tags = {
    managed_by  = "opentofu"
    environment = var.environment
  }

  # Custom tags override defaults
  final_tags = merge(local.default_tags, var.custom_tags)
}
```

### Defaults for Optional Object Attributes

To give optional object attributes default values, pass the default as the **second argument to
`optional()`** directly in the type constraint. OpenTofu fills in any omitted attribute with that
default — including nested objects — so you don't need a separate merge step.

```hcl
variable "server" {
  type = object({
    name = string
    port = optional(number, 8080)
    tls = optional(object({
      enabled     = optional(bool, false)
      min_version = optional(string, "TLS1.2")
    }), {}) # the trailing {} makes the whole tls object optional and lets its own defaults apply
  })
}

# Given input { name = "web" }, var.server resolves to:
#   { name = "web", port = 8080, tls = { enabled = false, min_version = "TLS1.2" } }
```

> **Note:** Older Terraform exposed a `defaults()` function for this, but it was an experiment that
> was removed once optional attributes went GA. Use the two-argument `optional(type, default)` form
> shown above — it is the supported approach in OpenTofu.

### `templatefile()` for Rendered Summaries

Combine variables and outputs to generate human-readable summaries:

```hcl
# templates/summary.tpl
Deployment Summary
==================
Environment : ${environment}
App Name    : ${app_name}
Replicas    : ${replicas}
Files Created:
%{ for f in files ~}
  - ${f}
%{ endfor ~}
Generated   : ${timestamp}

# main.tf
resource "local_file" "deployment_summary" {
  filename = "output/deployment-summary.txt"
  content  = templatefile("${path.module}/templates/summary.tpl", {
    environment = var.environment
    app_name    = local.app_name
    replicas    = local.replica_count
    files       = [for f in local_file.env_configs : f.filename]
    timestamp   = formatdate("YYYY-MM-DD hh:mm:ss ZZZ", timestamp())
  })
}
```

↑ [Back to Table of Contents](#table-of-contents)

---

## Exercises

### Exercise 1 — Easy: Typed Variables and Outputs

Take the Module 03 `local_file` example and add a proper variable interface:

1. Add `variable "files"` of type `map(string)` (keys = filenames, values = content)
2. Add `variable "output_dir"` of type `string` with default `"output"`
3. Add `variable "file_permission"` of type `string` with default `"0644"` and a validation that it matches the pattern `^0[0-7]{3}$`
4. Use `for_each` on `var.files` to create the files in `var.output_dir`
5. Add an output `file_map` that outputs `map(string)` of filename → absolute path
6. Add an output `file_count` that outputs the number of files created

---

### Exercise 2 — Medium: Complex Object Variable with Validation

Design a configuration for a "simulated app deployment":

1. Create a variable `app` of type `object({...})` with:
   - `name` (string, required, validation: 3–63 chars, lowercase alphanumeric + hyphens)
   - `environment` (string, required, validation: must be dev/staging/prod)
   - `replicas` (number, optional, default: 1, validation: 1–20)
   - `feature_flags` (map(bool), optional, default: `{}`)
   - `log_level` (string, optional, default: `"info"`, validation: must be trace/debug/info/warn/error)

2. Use `templatefile()` to generate an `output/app-config.json` file with all settings rendered

3. Create an output `app_summary` that is a human-readable string (not sensitive) describing the deployment

4. Demonstrate that passing invalid values (e.g., `environment = "test"`) produces clear validation error messages

---

### Exercise 3 — Hard: Full Variable Schema with sensitive Handling

Build a configuration that simulates a secrets-aware deployment:

1. Create a `map(object(...))` variable `services` where each service has:
   - `name` (string)
   - `port` (number)
   - `api_key` (string) — mark it sensitive via `sensitive = true` on the variable
   - `config` (map(string), optional)

2. For each service, create:
   - A `local_file` containing non-sensitive configuration (name, port, config)
   - A `local_sensitive_file` containing only the API key hash (use `sha256(each.value.api_key)` — never the raw key)
   - A `local_file` summary that lists all services with their ports (no API keys)

3. Add outputs:
   - `service_ports` — map of service name → port (not sensitive)
   - `service_count` — number of services
   - Attempt to output the raw API key and observe the error/redaction

4. Write a comment explaining what protections OpenTofu's `sensitive` flag does AND does NOT provide, and what additional steps are needed for production secrets management.

↑ [Back to Table of Contents](#table-of-contents)

---

## Further Reading

- [OpenTofu Input Variables](https://opentofu.org/docs/language/values/variables/) — Full variable reference including all arguments
- [OpenTofu Output Values](https://opentofu.org/docs/language/values/outputs/) — Output value reference
- [OpenTofu Local Values](https://opentofu.org/docs/language/values/locals/) — Locals reference
- [Type Constraints](https://opentofu.org/docs/language/expressions/type-constraints/) — Complete type system documentation
- [Sensitive Data in State](https://opentofu.org/docs/language/state/sensitive-data/) — Implications of sensitive values in state
- [Variable Validation](https://opentofu.org/docs/language/expressions/custom-conditions/#input-variable-validation) — Validation rule syntax and best practices

↑ [Back to Table of Contents](#table-of-contents)

---

## Summary

| Concept | Key Takeaway |
|---|---|
| Type constraints | Always type your variables; use `object({})` with `optional()` for structured configs |
| Validation | Add `validation` blocks to catch errors at plan time, not apply time |
| Resolution order | CLI `-var` > env vars > `*.auto.tfvars` > `terraform.tfvars` > defaults |
| Outputs | The public interface of a module; use `sensitive` for secret values |
| Locals | Reduce repetition; not overridable from outside; can reference other locals |
| Sensitive values | Redacted in CLI output but stored in plaintext in state — protect state access |
| `optional()` | Allow partial object construction with defaults |

↑ [Back to Table of Contents](#table-of-contents)

---

## Next Module →

**[Module 05 — State Management](../05-state-management/05-state-management.md)**

Deep-dive into the state file format, drift detection, state operations, and the complete backend ecosystem.


---

<sub>© 2026 UncleJS & Course OpenTofu contributors — licensed under [CC BY-NC-SA 4.0](../../LICENSE).<br>
You may share and adapt this material for non-commercial purposes with attribution.<br>
SPDX-License-Identifier: CC-BY-NC-SA-4.0</sub>