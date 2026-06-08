# Module 03 — Providers & Resources

<!-- SPDX-License-Identifier: CC-BY-NC-SA-4.0 -->

[![Module](https://img.shields.io/badge/Module-03-blue)](.)
[![Difficulty](https://img.shields.io/badge/Difficulty-Beginner-green)](.)
[![Time](https://img.shields.io/badge/Time-60%20min-lightgrey)](.)
[![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)

---

## Table of Contents

- [Overview](#overview)
- [What is a Provider?](#what-is-a-provider)
- [Provider Configuration Deep-Dive](#provider-configuration-deep-dive)
- [The `null` Provider](#the-null-provider)
- [The `local` Provider](#the-local-provider)
- [The `random` Provider](#the-random-provider)
- [Resource Meta-Arguments](#resource-meta-arguments)
- [Data Sources](#data-sources)
- [Internals: The Resource CRUD Cycle](#internals-the-resource-crud-cycle)
- [Exercises](#exercises)
- [Further Reading](#further-reading)
- [Summary](#summary)
- [Next Module →](#next-module-)

---

## Overview

Resources and providers are the core building blocks of every OpenTofu configuration. This module gives you a thorough understanding of how providers are configured, how the three provider-agnostic providers (`null`, `local`, `random`) work, and how every resource meta-argument controls lifecycle behaviour.

By the end of this module you will be able to:

- Explain how providers work as gRPC plugin binaries
- Configure provider aliases for multiple instances
- Use `null_resource`, `local_file`, and `random_*` resources
- Apply all five resource meta-arguments (`depends_on`, `count`, `for_each`, `lifecycle`, `provider`)
- Understand the difference between data sources and managed resources
- Trace the CRUD lifecycle of a resource through plan and apply

↑ [Back to Table of Contents](#table-of-contents)

---

## What is a Provider?

A **provider** is a plugin that implements the API integration for a specific platform or service. Providers:

- Declare which resource types and data sources exist (e.g., `local_file`, `null_resource`)
- Implement the CRUD (Create, Read, Update, Delete) operations for each resource type
- Handle authentication, API calls, and response parsing
- Run as separate OS processes, communicating with OpenTofu core via gRPC

### Provider Source Addresses

Every provider has a source address in the format `namespace/type`:

```
hashicorp/local    → registry.opentofu.org/hashicorp/local
hashicorp/null     → registry.opentofu.org/hashicorp/null
hashicorp/random   → registry.opentofu.org/hashicorp/random
```

The registry hostname (`registry.opentofu.org`) is implied when omitted. OpenTofu uses its own
registry by default, which serves the `hashicorp/*` providers (among many others).

### Provider Schema

When you run `tofu init`, OpenTofu downloads the provider binary and queries its schema. The schema describes:
- Every resource type the provider supports
- Every attribute of each resource (type, optionality, computed vs required)
- Every data source the provider supports

You can inspect a provider's schema directly:

```bash
tofu providers schema -json | jq '.provider_schemas["registry.opentofu.org/hashicorp/local"]'
```

> **Under the hood:** Provider schemas are fetched by calling the `GetProviderSchema` gRPC method on the provider binary. OpenTofu caches the schema in memory for the duration of the run and uses it to validate your HCL before sending any requests.

### Official vs Community Providers

| Type | Source | Examples |
|---|---|---|
| **Official** | `hashicorp/` namespace | `hashicorp/aws`, `hashicorp/google`, `hashicorp/local` |
| **Partner** | Verified publisher namespace | `datadog/datadog`, `cloudflare/cloudflare` |
| **Community** | Any namespace | `kreuzwerker/docker`, `loafoe/ssh` |
| **In-house** | Your own registry | `mycompany/internal-platform` |

↑ [Back to Table of Contents](#table-of-contents)

---

## Provider Configuration Deep-Dive

### Basic Provider Configuration

```hcl
# versions.tf
terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

# Minimal provider configuration (local needs no arguments)
provider "local" {}
```

Many providers require configuration (credentials, region, endpoint). The `local` provider needs none.

### `required_providers` Block

The `required_providers` block is the authoritative declaration of what providers your configuration needs:

```hcl
terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
```

Without this block, OpenTofu will still work but will not lock provider versions — dangerous in team environments.

### Provider Aliases

Use aliases when you need multiple configurations of the same provider (e.g., different directories, different credentials):

```hcl
# Two "local" providers writing to different directories
provider "local" {
  # default provider (no alias)
}

provider "local" {
  alias = "output_dir"
  # some providers accept configuration here
}

resource "local_file" "default_location" {
  provider = local          # uses the default provider
  filename = "/tmp/default.txt"
  content  = "default"
}

resource "local_file" "alternate_location" {
  provider = local.output_dir  # uses the aliased provider
  filename = "/tmp/output/alt.txt"
  content  = "alternate"
}
```

> **Note:** The `local` provider does not support configuration arguments, so both instances above are identical. In real-world usage, aliases are most useful for multi-region AWS or multi-account configurations.

### `configuration_aliases` in Modules

When a module requires a provider alias, it must declare it:

```hcl
# In a child module's versions.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [aws.us_east, aws.eu_west]
    }
  }
}
```

↑ [Back to Table of Contents](#table-of-contents)

---

## The `null` Provider

The `hashicorp/null` provider provides a single resource: `null_resource`. It has no real-world counterpart — it exists purely to model dependencies and trigger side effects via provisioners.

### `null_resource`

```hcl
resource "null_resource" "example" {
  # triggers is a map of values; when any value changes, the resource is
  # destroyed and recreated, re-running any provisioners
  triggers = {
    always_run = timestamp()           # always recreate
    config_hash = filemd5("config.txt") # recreate when file changes
  }

  provisioner "local-exec" {
    command = "echo 'Resource was created or recreated'"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "echo 'Resource is being destroyed'"
  }
}
```

### Triggers

The `triggers` argument is a `map(string)`. When any value in the map changes between applies, the `null_resource` is destroyed and recreated. This is the mechanism for re-running provisioners when inputs change.

Common trigger patterns:

```hcl
triggers = {
  # Always run the provisioner on every apply:
  always_run = timestamp()

  # Run when a specific file changes:
  script_hash = filemd5("${path.module}/scripts/setup.sh")

  # Run when a variable changes:
  environment = var.environment

  # Run when another resource changes (using its ID):
  depends_on_id = some_resource.example.id
}
```

### `local-exec` Provisioner

```hcl
provisioner "local-exec" {
  command     = "echo ${self.id} > /tmp/resource-id.txt"
  interpreter = ["/bin/bash", "-c"]  # optional; default is sh
  working_dir = "/tmp"               # optional
  environment = {                    # optional; merged with shell env
    MY_VAR = "value"
  }
}
```

> **Warning:** Provisioners are a **last resort**. They make configurations non-idempotent, break the plan/apply contract (OpenTofu cannot predict what a shell command will do), and complicate testing. Prefer native provider resources when available.

↑ [Back to Table of Contents](#table-of-contents)

---

## The `local` Provider

The `hashicorp/local` provider manages files on the local filesystem — perfect for provider-agnostic course examples.

### `local_file`

```hcl
resource "local_file" "config" {
  filename        = "${path.module}/output/config.txt"
  content         = "Hello from OpenTofu!"
  file_permission = "0644"   # optional; Unix permissions
}
```

### `local_sensitive_file`

Use this when the file content should be treated as sensitive (redacted from plan output):

```hcl
resource "local_sensitive_file" "secret" {
  filename        = "${path.module}/output/secret.txt"
  content         = var.api_key    # sensitive variable
  file_permission = "0600"
}
```

### Template Content

Combine `templatefile()` with `local_file` to generate config files:

```hcl
resource "local_file" "nginx_config" {
  filename = "${path.module}/output/nginx.conf"
  content  = templatefile("${path.module}/templates/nginx.conf.tpl", {
    server_name = var.server_name
    port        = var.port
    workers     = var.worker_count
  })
}
```

### Path Variables

OpenTofu provides built-in path references:

| Variable | Value |
|---|---|
| `path.module` | Absolute path to the current module directory |
| `path.root` | Absolute path to the root module directory |
| `path.cwd` | Current working directory |

Always use `path.module` for file paths in resources — makes the config portable.

### Data Source: `local_file`

Read an existing file (read-only; not managed by OpenTofu):

```hcl
data "local_file" "existing_config" {
  filename = "/etc/app/config.json"
}

output "config_content" {
  value = data.local_file.existing_config.content
}
```

↑ [Back to Table of Contents](#table-of-contents)

---

## The `random` Provider

The `hashicorp/random` provider generates random values. Values are generated once and stored in state — they do not change on subsequent applies (unless triggers/keepers change).

### `random_string`

```hcl
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
  # Result: "a4f7b2c1"
}

output "bucket_name" {
  value = "my-app-${random_string.suffix.result}"
}
```

### `random_pet`

Generates a human-readable random name (great for examples):

```hcl
resource "random_pet" "server_name" {
  length    = 2       # number of words: "happy-dolphin"
  separator = "-"     # word separator
  prefix    = "app"   # optional prefix: "app-happy-dolphin"
}
```

### `random_id`

Generates a random ID suitable for use as a resource suffix:

```hcl
resource "random_id" "deploy_id" {
  byte_length = 4
  # Provides: .hex ("a1b2c3d4"), .dec, .b64_url, .b64_std
}
```

### `random_integer`

```hcl
resource "random_integer" "port" {
  min = 1024
  max = 65535
}
```

### Keepers — Controlling Regeneration

**Keepers** are the mechanism for controlling when a random value is regenerated. When any keeper value changes between applies, the random resource is destroyed and recreated:

```hcl
resource "random_string" "db_password" {
  length           = 32
  special          = true
  override_special = "!@#$%"

  keepers = {
    # Regenerate if the environment changes
    environment = var.environment
    # Regenerate if explicitly rotated via a rotation counter
    rotation    = var.password_rotation_count
  }
}
```

Without keepers, the value never changes once set. With keepers, you have fine-grained control over when rotation happens.

↑ [Back to Table of Contents](#table-of-contents)

---

## Resource Meta-Arguments

Meta-arguments are accepted by **all** resources regardless of provider. They control how OpenTofu manages the resource's lifecycle.

### `depends_on` — Explicit Dependencies

```hcl
resource "local_file" "app_config" {
  filename = "/tmp/app.conf"
  content  = "ready"
}

resource "null_resource" "start_app" {
  # Even though start_app doesn't reference app_config's attributes,
  # we need to ensure the config file exists first
  depends_on = [local_file.app_config]

  provisioner "local-exec" {
    command = "echo 'Starting app with config'"
  }
}
```

> **Best practice:** Use implicit dependencies (attribute references) wherever possible. `depends_on` hides the relationship and makes the graph harder to understand. Only use it when there is a genuine dependency that cannot be expressed through attribute references.

### `count` — Multiple Instances

```hcl
variable "file_count" {
  type    = number
  default = 3
}

resource "local_file" "multi" {
  count    = var.file_count
  filename = "/tmp/file-${count.index}.txt"
  content  = "I am file number ${count.index}"
}

# Reference a specific instance
output "second_file" {
  value = local_file.multi[1].filename
}

# Reference all instances
output "all_files" {
  value = local_file.multi[*].filename
}
```

**Count caveats:**
- Instances are addressed by index: `resource[0]`, `resource[1]`, ...
- If you remove an element from the middle, all subsequent instances are shifted — OpenTofu destroys and recreates them
- For map-keyed instances where deletion should be safe, use `for_each`

### `for_each` — Map/Set Instances

```hcl
variable "files" {
  type = map(string)
  default = {
    config  = "This is the config file"
    readme  = "This is the readme"
    notes   = "These are my notes"
  }
}

resource "local_file" "each_file" {
  for_each = var.files
  filename = "/tmp/${each.key}.txt"
  content  = each.value
}

# Reference a specific instance by key
output "config_path" {
  value = local_file.each_file["config"].filename
}

# Reference all instances
output "all_paths" {
  value = { for k, v in local_file.each_file : k => v.filename }
}
```

**`for_each` vs `count`:**

| Feature | `count` | `for_each` |
|---|---|---|
| Index type | Integer | String (map key or set element) |
| Deletion of one item | Re-indexes all subsequent items | Removes only the deleted key |
| Good for | Identical resources with a numeric count | Named, distinct resources |
| Access in resource | `count.index` | `each.key`, `each.value` |

### `lifecycle` — Lifecycle Customisation

```hcl
resource "local_file" "critical" {
  filename = "/tmp/critical.txt"
  content  = "Do not delete me!"

  lifecycle {
    # Create the new resource before destroying the old one
    # (avoids downtime for replacements)
    create_before_destroy = true

    # Prevent accidental deletion
    prevent_destroy = true

    # Ignore changes to these attributes (don't treat as drift)
    ignore_changes = [
      content,  # ignore if someone manually edits the file
    ]

    # Trigger replacement when this expression changes
    replace_triggered_by = [
      null_resource.rebuild_trigger.id
    ]
  }
}
```

| Option | Effect |
|---|---|
| `create_before_destroy = true` | New resource created before old one is deleted (zero-downtime replacement) |
| `prevent_destroy = true` | `tofu destroy` or resource deletion in plan will return an error |
| `ignore_changes = [...]` | Listed attributes are excluded from drift detection |
| `replace_triggered_by = [...]` | Destroy+recreate this resource when any listed expression changes |

### `provider` — Route to a Specific Provider Instance

```hcl
resource "local_file" "alt" {
  provider = local.output_dir   # use the aliased provider
  filename  = "/tmp/output/alt.txt"
  content   = "alternate provider"
}
```

↑ [Back to Table of Contents](#table-of-contents)

---

## Data Sources

Data sources are **read-only** resource queries. They read existing infrastructure or external data without creating or managing it.

```hcl
# Read an existing file
data "local_file" "existing" {
  filename = "/etc/hostname"
}

output "hostname" {
  value = data.local_file.existing.content
}
```

### Data Source Refresh Behaviour

Data sources are refreshed on every `tofu plan` by default. This means:
- They always reflect the current state of the external resource
- They are **not** stored in state the same way managed resources are
- Their values can change between plans without any action by OpenTofu

### `depends_on` with Data Sources — The Footgun

A common mistake is using a data source to read something that a resource in the same config creates. Without `depends_on`, OpenTofu may try to read the data source before the resource is created:

```hcl
resource "local_file" "setup" {
  filename = "/tmp/setup-complete"
  content  = "done"
}

# This data source reads the file created above.
# Without depends_on, OpenTofu reads it at plan time — before the file exists!
data "local_file" "read_back" {
  filename   = local_file.setup.filename
  depends_on = [local_file.setup]   # forces read AFTER creation
}
```

> **Under the hood:** During plan, OpenTofu reads data sources as part of the refresh phase. If a data source depends on a resource that does not yet exist, its values will be unknown (`null`). Adding `depends_on` forces OpenTofu to defer the data source read until apply time.

↑ [Back to Table of Contents](#table-of-contents)

---

## Internals: The Resource CRUD Cycle

Understanding how OpenTofu calls provider functions helps you predict plan output and debug unexpected behaviour.

### The Four Operations

| Operation | When | Provider function |
|---|---|---|
| **Create** | Resource in config, not in state | `CreateResource` |
| **Read** | During refresh — resource in state | `ReadResource` |
| **Update** | Resource in state, attributes changed | `UpdateResource` |
| **Delete** | Resource in state, not in config | `DeleteResource` |

Some attributes are **ForceNew** — changing them destroys and recreates the resource instead of updating it. In plan output these appear as `-/+` (destroy + create).

### Planned vs Actual Values

During `tofu plan`, some values are **unknown** — they won't be known until the resource is actually created. These appear in plan output as `(known after apply)`.

```
# local_file.example will be created
+ resource "local_file" "example" {
    + content              = "Hello!"
    + filename             = "/tmp/hello.txt"
    + id                   = (known after apply)  # computed by provider
  }
```

Unknown values **cannot** be used in `count` or `for_each` — OpenTofu needs to know the count/keys at plan time. This is a common source of the `Error: Invalid count argument` error.

↑ [Back to Table of Contents](#table-of-contents)

---

## Exercises

### Exercise 1 — Easy: Create a Local File

Create a configuration that:
1. Uses the `local` provider
2. Creates a file at `output/hello.txt` with the content `Hello, OpenTofu!`
3. Creates a second file at `output/info.txt` with the content `Generated by OpenTofu on <timestamp>`
4. Outputs the path of both files

Run `tofu init && tofu apply` and verify the files are created.

---

### Exercise 2 — Medium: for_each with random_pet

Create a configuration that:
1. Defines a `map(string)` variable `environments` with keys `dev`, `staging`, `prod` and values describing each environment
2. Uses `for_each` to create one `local_file` per environment at `output/<env>-config.txt`
3. For each file, the content should include the environment name, description, and a `random_pet` name (use `for_each` on `random_pet` too, keyed by environment)
4. Outputs a map of environment → file path and a map of environment → pet name
5. Demonstrates that deleting the `staging` entry from the variable causes only the staging file to be destroyed (not staging + prod, as would happen with `count`)

---

### Exercise 3 — Hard: null_resource Trigger Chain

Create a configuration that:
1. Has a `local_file` resource that writes a "config" file (content controlled by a variable)
2. Has a `null_resource` that "processes" the config (local-exec: append a timestamp to a log file) — it should only re-run when the config file content changes (use `filemd5` trigger)
3. Has a second `null_resource` that "notifies" (local-exec: write a notification file) — it should only run after the processor runs AND only when the processor ran (use `depends_on` + a trigger referencing the processor's id)
4. Run `tofu apply` twice with no changes — confirm only the first apply triggers the provisioners
5. Change the config variable value and run `tofu apply` — confirm only the processor and notifier run
6. Explain in comments why `timestamp()` as a trigger makes a resource always-recreate, and when that is and is not desirable

↑ [Back to Table of Contents](#table-of-contents)

---

## Further Reading

- [OpenTofu Providers Documentation](https://opentofu.org/docs/language/providers/) — Official provider reference
- [hashicorp/local Provider Docs](https://registry.terraform.io/providers/hashicorp/local/latest/docs) — Full local provider reference
- [hashicorp/null Provider Docs](https://registry.terraform.io/providers/hashicorp/null/latest/docs) — null_resource reference
- [hashicorp/random Provider Docs](https://registry.terraform.io/providers/hashicorp/random/latest/docs) — All random resources
- [Resource Meta-Arguments](https://opentofu.org/docs/language/meta-arguments/) — Official meta-argument docs
- [Provisioners (Last Resort)](https://opentofu.org/docs/language/resources/provisioners/) — When to use and avoid provisioners

↑ [Back to Table of Contents](#table-of-contents)

---

## Summary

| Concept | Key Takeaway |
|---|---|
| Provider | A gRPC plugin binary implementing CRUD for a platform's resources |
| `required_providers` | Always declare providers and version constraints |
| `null_resource` | Dependency modelling and side effects via provisioners |
| `local_file` | File management on the local filesystem |
| `random_*` | Generate random values; use keepers to control regeneration |
| `count` | Numeric multi-instance; fragile for ordered changes |
| `for_each` | Key-based multi-instance; safe for named resources |
| `lifecycle` | Fine-grained control over create/update/delete behaviour |
| Data sources | Read-only queries; use `depends_on` if reading post-creation resources |

↑ [Back to Table of Contents](#table-of-contents)

---

## Next Module →

**[Module 04 — Variables & Outputs](../04-variables-and-outputs/04-variables-and-outputs.md)**

Master every variable type, validation rules, sensitive values, locals, and complex variable patterns.


---

<sub>© 2026 UncleJS & Course OpenTofu contributors — licensed under [CC BY-NC-SA 4.0](../../LICENSE).<br>
You may share and adapt this material for non-commercial purposes with attribution.<br>
SPDX-License-Identifier: CC-BY-NC-SA-4.0</sub>