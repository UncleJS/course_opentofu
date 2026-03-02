<!--
SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->

# Module 12 — Advanced Patterns

[![Module](https://img.shields.io/badge/module-12%20of%2014-blue?style=flat-square)](../..)
[![Difficulty](https://img.shields.io/badge/difficulty-Advanced-red?style=flat-square)](../..)
[![Time](https://img.shields.io/badge/time-120%20min-lightgrey?style=flat-square)](../..)
[![License](https://img.shields.io/badge/license-CC%20BY--NC--SA%204.0-green?style=flat-square)](../../LICENSE)

> Master dynamic resource generation, meta-arguments, provider aliasing, lifecycle hooks, generative modules, and the full OpenTofu DAG execution model.

---

## Table of Contents

1. [Dynamic Blocks](#1-dynamic-blocks)
2. [Meta-arguments: `depends_on`, `lifecycle`, `precondition`, `postcondition`](#2-meta-arguments-depends_on-lifecycle-precondition-postcondition)
3. [Provider Aliasing & Multi-Region Patterns](#3-provider-aliasing--multi-region-patterns)
4. [The `moved` Block](#4-the-moved-block)
5. [`import` Block (OpenTofu 1.5+)](#5-import-block-opentofu-15)
6. [Generated Configuration (`-generate-config-out`)](#6-generated-configuration--generate-config-out)
7. [Complex Variable Types & Object Validation](#7-complex-variable-types--object-validation)
8. [DAG Internals & Parallelism](#8-dag-internals--parallelism)
9. [Exercises](#9-exercises)
10. [Further Reading](#10-further-reading)

---

## 1. Dynamic Blocks

`dynamic` blocks let you generate repeated nested blocks programmatically — eliminating copy-paste in resource definitions.

### Syntax

```hcl
resource "aws_security_group" "example" {
  name = "example"

  dynamic "ingress" {
    for_each = var.ingress_rules

    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }
}
```

### Rules

- `dynamic "<BLOCK_TYPE>"` matches the name of the nested block type
- The iterator variable defaults to the block type name (`ingress` above)
- Use `iterator = "rule"` to rename it: `rule.value.from_port`
- `for_each` accepts any collection (list, set, map)
- Dynamic blocks can be nested inside dynamic blocks

> **Under the hood:** During the plan phase, OpenTofu evaluates `for_each` first, then expands `content` into N copies of the nested block. The resulting schema is identical to hand-written blocks — there is no runtime overhead.

[↑ Back to Table of Contents](#table-of-contents)

---

## 2. Meta-arguments: `depends_on`, `lifecycle`, `precondition`, `postcondition`

### `depends_on` — explicit dependencies

Use when OpenTofu cannot infer the dependency from attribute references:

```hcl
resource "null_resource" "db_migration" {
  depends_on = [aws_db_instance.main]  # explicit: no attribute reference exists
}
```

> **Caution:** `depends_on` adds an edge to the DAG that forces sequential execution. Over-using it defeats OpenTofu's parallelism engine. Prefer implicit references wherever possible.

### `lifecycle` — control resource replacement behaviour

```hcl
resource "local_file" "cert" {
  filename = "/etc/ssl/app.crt"
  content  = tls_self_signed_cert.app.cert_pem

  lifecycle {
    # Create the replacement before destroying the original
    create_before_destroy = true

    # Never destroy this resource (useful for databases, certs)
    prevent_destroy = true

    # Ignore changes to content made outside OpenTofu
    ignore_changes = [content]

    # Replace only if a specific attribute changes
    replace_triggered_by = [tls_private_key.app.id]
  }
}
```

### `precondition` — validate assumptions before apply

```hcl
resource "local_file" "deployment" {
  filename = "/tmp/deploy.json"
  content  = "{}"

  lifecycle {
    precondition {
      condition     = var.environment != "prod" || var.approved_by != ""
      error_message = "Production deployments require approved_by to be set."
    }
  }
}
```

### `postcondition` — validate outcomes after apply

```hcl
resource "local_file" "config" {
  filename = "/tmp/config.json"
  content  = jsonencode({ version = var.app_version })

  lifecycle {
    postcondition {
      condition     = fileexists(self.filename)
      error_message = "Config file was not created at ${self.filename}."
    }
  }
}
```

> **Under the hood:** `precondition` runs during the plan phase — before any resource is mutated. `postcondition` runs after the resource is applied — it can reference `self.*` attributes. Both use the same expression evaluator as `assert` in test files.

[↑ Back to Table of Contents](#table-of-contents)

---

## 3. Provider Aliasing & Multi-Region Patterns

Provider aliasing lets you configure the same provider multiple times:

```hcl
provider "aws" {
  region = "us-east-1"
  alias  = "us_east"
}

provider "aws" {
  region = "eu-west-1"
  alias  = "eu_west"
}

resource "aws_s3_bucket" "us" {
  provider = aws.us_east
  bucket   = "my-bucket-us"
}

resource "aws_s3_bucket" "eu" {
  provider = aws.eu_west
  bucket   = "my-bucket-eu"
}
```

### Passing aliased providers to modules

```hcl
module "cdn" {
  source = "./modules/cdn"

  providers = {
    aws         = aws.us_east   # default provider for the module
    aws.replica = aws.eu_west   # aliased provider (module must declare it)
  }
}
```

Inside the module, declare the alias:

```hcl
# modules/cdn/versions.tf
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.replica]
    }
  }
}
```

[↑ Back to Table of Contents](#table-of-contents)

---

## 4. The `moved` Block

`moved` lets you rename or move resources in state **without destroying and recreating** them. Essential for safe module refactoring.

### Renaming a resource

```hcl
# Before: resource "local_file" "config" {}
# After:  resource "local_file" "app_config" {}

moved {
  from = local_file.config
  to   = local_file.app_config
}
```

### Moving into a module

```hcl
moved {
  from = local_file.config
  to   = module.app.local_file.config
}
```

### Moving with `for_each`

```hcl
moved {
  from = local_file.legacy[0]
  to   = local_file.config["primary"]
}
```

> **Under the hood:** `moved` blocks are processed during the plan phase before any resource diff is computed. OpenTofu rewrites the state addresses, then computes a plan against the new addresses. The result is a no-op diff for the moved resource — confirming no replacement occurs.

[↑ Back to Table of Contents](#table-of-contents)

---

## 5. `import` Block (OpenTofu 1.5+)

Bring existing infrastructure under OpenTofu management without recreating it:

```hcl
# Declarative import (OpenTofu 1.5+)
import {
  id = "existing-bucket-name"
  to = aws_s3_bucket.main
}

resource "aws_s3_bucket" "main" {
  bucket = "existing-bucket-name"
}
```

When you run `tofu plan`, OpenTofu shows the import diff. When you run `tofu apply`, it records the resource in state without touching the real infrastructure.

### Generate config from existing resources

```bash
# OpenTofu writes the resource block for you
tofu plan -generate-config-out=imported.tf
```

This produces a complete `.tf` file with all attributes populated from the real resource — a huge time-saver when importing large existing deployments.

[↑ Back to Table of Contents](#table-of-contents)

---

## 6. Generated Configuration (`-generate-config-out`)

```bash
tofu plan \
  -generate-config-out=generated.tf \
  -var-file=envs/prod.tfvars
```

OpenTofu scans all `import` blocks, fetches the real resource attributes from the provider, and writes a complete `.tf` resource block. You then:

1. Review `generated.tf`
2. Adjust to match your coding conventions
3. Delete the `import {}` block
4. Run `tofu plan` — should show no changes

[↑ Back to Table of Contents](#table-of-contents)

---

## 7. Complex Variable Types & Object Validation

### Object type with optional attributes

```hcl
variable "service" {
  type = object({
    name        = string
    port        = number
    protocol    = optional(string, "tcp")
    healthcheck = optional(object({
      path     = string
      interval = optional(number, 30)
    }))
  })
}
```

### List of objects with validation

```hcl
variable "ingress_rules" {
  type = list(object({
    from_port = number
    to_port   = number
    protocol  = string
  }))

  validation {
    condition = alltrue([
      for r in var.ingress_rules :
      r.from_port <= r.to_port
    ])
    error_message = "from_port must be <= to_port in all ingress rules."
  }

  validation {
    condition = alltrue([
      for r in var.ingress_rules :
      contains(["tcp", "udp", "icmp", "-1"], r.protocol)
    ])
    error_message = "protocol must be tcp, udp, icmp, or -1 (all)."
  }
}
```

### `sensitive` type modifier

```hcl
variable "db_password" {
  type      = string
  sensitive = true  # value redacted in plan/apply output and state display
}
```

> **Under the hood:** `sensitive = true` wraps the value in a "marked" type in OpenTofu's type system. Marked values propagate through expressions — any output that *uses* a sensitive value is automatically marked sensitive too, unless you explicitly call `nonsensitive()`.

[↑ Back to Table of Contents](#table-of-contents)

---

## 8. DAG Internals & Parallelism

OpenTofu builds a **Directed Acyclic Graph (DAG)** of all resources before executing any operation. Understanding this graph explains *why* certain patterns work and others deadlock.

### How the DAG is built

1. **Node creation** — one node per resource, data source, module, provider, and variable
2. **Edge creation** — an edge A→B means "A must complete before B starts"
   - Implicit edges: attribute references (`resource.foo.id` → `resource.bar`)
   - Explicit edges: `depends_on`
3. **Walk** — OpenTofu walks the DAG in topological order, running nodes in parallel when no dependency exists

### Parallelism

```bash
# Default: up to 10 parallel operations
tofu apply

# Increase for large deployments
tofu apply -parallelism=20

# Serialize (useful for debugging)
tofu apply -parallelism=1
```

### Detecting cycles

If you create a circular dependency (A depends on B, B depends on A), OpenTofu will error:

```
Error: Cycle: resource.a, resource.b
```

Fix by removing one of the dependency edges — usually by using `depends_on` more carefully or restructuring locals.

### Visualising the graph

```bash
tofu graph | dot -Tsvg > graph.svg
# Requires graphviz: apt install graphviz / brew install graphviz
```

> **Under the hood:** The graph walk uses a concurrent worker pool. Each worker claims a node once all its prerequisites are marked "done". The pool size is controlled by `-parallelism`. For destroy operations the graph is reversed — leaf nodes (no dependents) are destroyed first.

[↑ Back to Table of Contents](#table-of-contents)

---

## 9. Exercises

### Exercise 1 — Easy: Dynamic blocks

In the examples configuration, a `dynamic` block generates a variable number of file sections. Change `var.section_count` and observe the plan:

```bash
cd modules/12-advanced-patterns/examples
tofu init
tofu apply -var="section_count=1" -auto-approve
tofu plan  -var="section_count=4"
# Observe: plan shows +3 new file sections
```

---

### Exercise 2 — Medium: Safe refactor with `moved`

The example config renames a resource. Perform the rename without destroying the file:

```bash
tofu apply -auto-approve  # creates local_file.legacy_name
# Now apply the moved block (already written in main.tf)
tofu plan   # should show: "local_file.legacy_name has moved to local_file.new_name"
tofu apply  # applies the state rename — no file is touched
```

---

### Exercise 3 — Hard: Preconditions + postconditions

Extend the example to enforce a business rule:
- **precondition:** `var.environment == "prod"` requires `var.approved_by != ""`
- **postcondition:** every generated file must be readable (`fileexists(self.filename)`)

```bash
# This should fail the precondition:
tofu apply -var="environment=prod" -var="approved_by=" -auto-approve

# This should succeed:
tofu apply -var="environment=prod" -var="approved_by=alice" -auto-approve
```

[↑ Back to Table of Contents](#table-of-contents)

---

## 10. Further Reading

- [OpenTofu: `dynamic` Blocks](https://opentofu.org/docs/language/expressions/dynamic-blocks/)
- [OpenTofu: `lifecycle` meta-argument](https://opentofu.org/docs/language/meta-arguments/lifecycle/)
- [OpenTofu: `moved` block](https://opentofu.org/docs/language/modules/develop/refactoring/)
- [OpenTofu: `import` block](https://opentofu.org/docs/language/import/)
- [OpenTofu: Custom conditions (precondition/postcondition)](https://opentofu.org/docs/language/expressions/custom-conditions/)
- [OpenTofu: Graph command](https://opentofu.org/docs/cli/commands/graph/)

[↑ Back to Table of Contents](#table-of-contents)


---

<sub>© 2026 UncleJS & Course OpenTofu contributors — licensed under [CC BY-NC-SA 4.0](../../LICENSE).<br>
You may share and adapt this material for non-commercial purposes with attribution.<br>
SPDX-License-Identifier: CC-BY-NC-SA-4.0</sub>