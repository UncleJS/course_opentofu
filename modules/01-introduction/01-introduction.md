# Module 01 — Introduction to OpenTofu

<!-- SPDX-License-Identifier: CC-BY-NC-SA-4.0 -->

[![Module](https://img.shields.io/badge/Module-01-blue)](.)
[![Difficulty](https://img.shields.io/badge/Difficulty-Beginner-green)](.)
[![Time](https://img.shields.io/badge/Time-45%20min-lightgrey)](.)
[![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)

---

## Table of Contents

- [Overview](#overview)
- [What is Infrastructure as Code?](#what-is-infrastructure-as-code)
- [OpenTofu vs Terraform — The Full Story](#opentofu-vs-terraform--the-full-story)
- [How OpenTofu Works Internally](#how-opentofu-works-internally)
- [The Core Workflow](#the-core-workflow)
- [HCL Primer](#hcl-primer)
- [Exercises](#exercises)
- [Further Reading](#further-reading)
- [Summary](#summary)
- [Next Module →](#next-module-)

---

## Overview

This module introduces the foundational concepts behind Infrastructure as Code (IaC) and explains what OpenTofu is, why it exists, and how it works under the hood. By the end of this module you will understand:

- The difference between mutable and immutable infrastructure
- The declarative vs imperative programming model
- Where OpenTofu fits in the IaC tool landscape
- The OpenTofu/Terraform split and governance model
- How OpenTofu plans and applies changes using a dependency graph
- The basics of HCL syntax

No code is written in this module — it is entirely conceptual and forms the mental model you will build on throughout the course.

↑ [Back to Table of Contents](#table-of-contents)

---

## What is Infrastructure as Code?

Infrastructure as Code (IaC) is the practice of managing and provisioning computing infrastructure through machine-readable configuration files rather than through manual processes or interactive configuration tools.

### The Problem IaC Solves

Before IaC, infrastructure was typically managed by:
- Clicking through cloud console UIs (error-prone, not reproducible)
- Running ad-hoc shell scripts (brittle, hard to audit)
- Manually SSHing into servers (no record of changes)

These approaches lead to **snowflake servers** — unique, hand-crafted machines that cannot be reliably reproduced. When they fail, recovery is slow and inconsistent.

IaC solves this by treating infrastructure configuration the same way developers treat application code: version-controlled, reviewed, tested, and deployed in a repeatable pipeline.

### Mutable vs Immutable Infrastructure

| Model | Description | Example |
|---|---|---|
| **Mutable** | Servers are updated in-place over time (patched, reconfigured) | Running `apt upgrade` on a running VM |
| **Immutable** | Servers are never modified; new versions replace old ones | Building a new VM image and swapping it in |

OpenTofu supports both models. Most cloud resources (VMs, databases) can be updated in-place or replaced. The `lifecycle` block gives you control.

### Declarative vs Imperative

| Style | Description | Example |
|---|---|---|
| **Imperative** | You specify the exact steps to reach the desired state | `aws ec2 run-instances ...` then `aws ec2 describe-instances ...` |
| **Declarative** | You specify the desired end state; the tool figures out the steps | `resource "aws_instance" "web" { ... }` |

OpenTofu is **declarative**. You describe what you want; OpenTofu determines what needs to be created, updated, or deleted to achieve it.

### IaC Tool Landscape

| Tool | Style | Language | Scope | Notes |
|---|---|---|---|---|
| **OpenTofu** | Declarative | HCL / JSON | Multi-cloud | Community fork of Terraform |
| **Terraform** | Declarative | HCL / JSON | Multi-cloud | Now BSL licensed (post-Aug 2023) |
| **Pulumi** | Declarative | TypeScript / Python / Go / C# | Multi-cloud | Code-first approach |
| **AWS CloudFormation** | Declarative | YAML / JSON | AWS only | Native AWS, no extra install |
| **AWS CDK** | Imperative + Declarative | TypeScript / Python / Java | AWS only | Generates CloudFormation |
| **Ansible** | Imperative | YAML | Config + infra | Better for config management |
| **Crossplane** | Declarative | YAML (Kubernetes CRDs) | Multi-cloud | K8s-native IaC |

↑ [Back to Table of Contents](#table-of-contents)

---

## OpenTofu vs Terraform — The Full Story

### The Licence Change

In August 2023, HashiCorp changed Terraform's licence from the open-source **Mozilla Public License 2.0 (MPL-2.0)** to the **Business Source License 1.1 (BSL/BUSL)**. Under BSL, commercial use of Terraform by competitors of HashiCorp is restricted.

This alarmed many companies and practitioners who had built businesses, tools, and workflows on top of Terraform's open-source promise.

### The Fork

In September 2023, a group of companies (including Gruntwork, Spacelift, env0, Scalr, and others) announced **OpenTofu** as a community-governed fork of the last MPL-licensed version of Terraform (1.5.x).

OpenTofu was accepted into the **Linux Foundation** in October 2023, giving it a neutral governance structure independent of any single company. This mirrors how other major infrastructure projects (Kubernetes, containerd) are governed.

### Timeline

| Date | Event |
|---|---|
| Aug 2023 | HashiCorp changes Terraform licence to BSL 1.1 |
| Sep 2023 | OpenTofu fork announced |
| Oct 2023 | OpenTofu accepted into Linux Foundation |
| Jan 2024 | OpenTofu 1.6.0 released (first stable release) |
| Mar 2024 | OpenTofu 1.7.0 — state encryption, `removed` block |
| Sep 2024 | OpenTofu 1.8.0 — provider functions, early eval |
| Jan 2025 | OpenTofu 1.9.0 — `tofu test` improvements |
| Mar 2025 | OpenTofu 1.10.0 — ephemeral resources, deferred changes |

### Feature Parity and Divergence

OpenTofu started as a fork at parity with Terraform 1.5. Since then, both projects have added features independently.

| Feature | OpenTofu | Terraform |
|---|---|---|
| State encryption at rest | ✅ 1.7+ | ❌ Not available |
| Provider functions | ✅ 1.8+ | ✅ 1.8+ |
| Ephemeral resources | ✅ 1.10+ | ✅ 1.10+ |
| `removed` block | ✅ 1.7+ | ✅ 1.7+ |
| `import` block | ✅ 1.5+ | ✅ 1.5+ |
| `check` block | ✅ 1.5+ | ✅ 1.5+ |
| Registry compatibility | ✅ (same registry) | ✅ |
| Licence | MPL-2.0 | BSL 1.1 |
| Governance | Linux Foundation | HashiCorp / IBM |

### When to Choose OpenTofu

- You want a permissively licensed, community-governed tool
- Your company has restrictions on BSL-licensed software
- You want state encryption at rest natively
- You are building tooling or services around IaC
- You are migrating from Terraform — the migration path is straightforward

↑ [Back to Table of Contents](#table-of-contents)

---

## How OpenTofu Works Internally

Understanding the internals makes you a significantly better practitioner. Here is what happens when you run `tofu plan` or `tofu apply`.

### The Provider Protocol (gRPC)

OpenTofu's architecture is a **plugin system**. The core engine does not know anything about AWS, GCP, or any specific platform. Instead, it communicates with **provider plugins** via **gRPC** — a high-performance remote procedure call protocol.

```
┌─────────────────────────────────────────────────────┐
│                  OpenTofu Core                      │
│  (HCL parser, DAG, state management, plan engine)  │
└────────────────────┬────────────────────────────────┘
                     │ gRPC (Protocol v5/v6)
          ┌──────────┴──────────┐
          │                     │
   ┌──────▼──────┐       ┌──────▼──────┐
   │  local      │       │  random     │
   │  provider   │       │  provider   │
   │  (binary)   │       │  (binary)   │
   └─────────────┘       └─────────────┘
```

Each provider is a separate OS process. The provider binary:
1. Implements the gRPC provider protocol
2. Exposes resource schemas (what arguments/attributes exist)
3. Implements CRUD operations for each resource type

> **Under the hood:** When you run `tofu init`, OpenTofu downloads provider binaries from the registry and stores them in `.terraform/providers/`. When you run `plan` or `apply`, OpenTofu launches each required provider as a child process and communicates with it via gRPC over stdin/stdout.

### The Dependency Graph (DAG)

Before executing any operations, OpenTofu builds a **Directed Acyclic Graph (DAG)** of all resources in your configuration.

- **Directed**: edges represent dependencies (A depends on B → edge from A to B)
- **Acyclic**: no circular dependencies allowed (would cause infinite loops)

OpenTofu builds this graph from:
1. **Implicit dependencies**: when one resource references an attribute of another (`local_file.a.filename` in resource B creates an edge B → A)
2. **Explicit dependencies**: when you use `depends_on = [resource.a]`

Example graph for a configuration with 3 resources:

```
random_pet.name ──► local_file.config ──► null_resource.notify
```

OpenTofu can execute independent branches of the graph **in parallel** (default parallelism: 10).

> **Under the hood:** The graph is a topological sort. Resources with no dependencies are at the roots and execute first. Resources at the leaves execute last. You can visualise it with `tofu graph | dot -Tsvg > graph.svg` (requires Graphviz).

### Plan Phases

When you run `tofu plan`, three things happen in sequence:

1. **Refresh** — OpenTofu reads the current state of every managed resource from the provider. The state file is updated with real-world values. (Skip with `-refresh=false`)

2. **Diff** — OpenTofu compares the refreshed state against your HCL desired state. For each resource, it determines: no change / update-in-place / destroy + recreate / create new.

3. **Output** — The diff is formatted as human-readable plan output and (optionally) saved as a binary plan artifact with `-out=plan.bin`.

### Apply Phases

When you run `tofu apply` (or `tofu apply plan.bin`):

1. OpenTofu walks the DAG in dependency order
2. For each node in the graph, it calls the provider's appropriate CRUD function: `Create`, `Update`, or `Delete`
3. After each resource is created/updated, its attributes are written back to state
4. If any resource fails, the apply stops and the error is reported; already-applied changes remain in state

↑ [Back to Table of Contents](#table-of-contents)

---

## The Core Workflow

Every OpenTofu workflow follows the same four commands:

```bash
# 1. Initialise the working directory
tofu init

# 2. Preview changes (no real-world changes made)
tofu plan

# 3. Apply changes
tofu apply

# 4. Remove all managed resources
tofu destroy
```

### `tofu init`

- Downloads provider plugins declared in `required_providers`
- Sets up the backend (local by default)
- Installs child module sources
- Creates `.terraform/` directory and `.terraform.lock.hcl`

Must be re-run when you:
- Add a new provider
- Change backend configuration
- Add a new module source

### `tofu plan`

- Reads current state (from state file and provider refresh)
- Compares with desired state (your HCL)
- Outputs a diff: `+` create, `~` update, `-` destroy, `-/+` destroy and recreate

### `tofu apply`

- Runs a fresh plan (unless given a plan artifact)
- Asks for confirmation: `Do you want to perform these actions? yes`
- Executes the changes
- Updates the state file

### `tofu destroy`

- Plans the destruction of all managed resources
- Asks for confirmation
- Deletes all resources and clears state

↑ [Back to Table of Contents](#table-of-contents)

---

## HCL Primer

HashiCorp Configuration Language (HCL) is the language you write OpenTofu configurations in. It is designed to be human-readable while remaining machine-parseable.

### File Structure

OpenTofu loads **all** `.tf` files in the current directory. File names are arbitrary — by convention:

| File | Purpose |
|---|---|
| `main.tf` | Primary resources |
| `variables.tf` | Input variable declarations |
| `outputs.tf` | Output value declarations |
| `versions.tf` | `terraform {}` block with version constraints |
| `locals.tf` | Local value declarations |

### Block Types

```hcl
# Resource block: type = "resource", labels = ["local_file", "example"]
resource "local_file" "example" {
  filename = "/tmp/hello.txt"
  content  = "Hello, OpenTofu!"
}

# Variable block
variable "greeting" {
  type        = string
  description = "The greeting message"
  default     = "Hello"
}

# Output block
output "file_path" {
  value = local_file.example.filename
}

# Local values block
locals {
  message = "${var.greeting}, OpenTofu!"
}

# Terraform settings block
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

### Types

HCL supports the following value types:

| Type | Example |
|---|---|
| `string` | `"hello"` |
| `number` | `42`, `3.14` |
| `bool` | `true`, `false` |
| `list(type)` | `["a", "b", "c"]` |
| `map(type)` | `{ key = "value" }` |
| `set(type)` | Like list but unordered and unique |
| `object({...})` | `{ name = "Alice", age = 30 }` |
| `tuple([...])` | `["Alice", 30, true]` |
| `any` | Any type (avoid in validated code) |

### String Interpolation

```hcl
variable "name" {
  default = "world"
}

output "greeting" {
  value = "Hello, ${var.name}!"
}
```

### Comments

```hcl
# This is a single-line comment
// This is also a single-line comment

/* This is a
   multi-line comment */
```

### `.tf` vs `.tofu` Extensions

Both `.tf` and `.tofu` file extensions are supported by OpenTofu. The `.tofu` extension is OpenTofu-specific and useful when you want to make it explicit that a file is not intended for Terraform. Most of the ecosystem uses `.tf`.

↑ [Back to Table of Contents](#table-of-contents)

---

## Exercises

### Exercise 1 — Easy: IaC Anti-Pattern Review

Examine the following shell script that provisions infrastructure. Identify at least **5 IaC anti-patterns** it exhibits and explain why each is problematic.

```bash
#!/bin/bash
# deploy.sh - "Deploy the app"

# Create directories
ssh admin@10.0.1.5 "mkdir -p /opt/myapp/config"

# Copy config
scp config.json admin@10.0.1.5:/opt/myapp/config/

# Install dependencies
ssh admin@10.0.1.5 "apt-get install -y nodejs npm"

# Set port based on today's day of week
if [ $(date +%u) -lt 6 ]; then
  PORT=3000
else
  PORT=8080
fi

ssh admin@10.0.1.5 "echo PORT=$PORT >> /opt/myapp/config/env"

# Start app (don't fail if already running)
ssh admin@10.0.1.5 "nohup node /opt/myapp/server.js &" || true

echo "Done! Probably."
```

**Expected findings include:** non-idempotent operations, hardcoded IPs, no state tracking, no error handling, environment-specific logic embedded in deployment script, undocumented side effects, no plan/preview step, no audit trail.

---

### Exercise 2 — Medium: Draw the Dependency Graph

Given the following (pseudocode) configuration, draw the dependency graph by hand, then answer the questions below:

```
Resource A: random_pet.app_name
Resource B: local_file.config
  - references random_pet.app_name.id
Resource C: local_file.readme
  - references local_file.config.filename
Resource D: null_resource.validate
  - depends_on = [local_file.config, local_file.readme]
Resource E: random_string.token
  (no dependencies)
```

Questions:
1. Which resources can be created in parallel on the first apply?
2. Which resource is created last?
3. If Resource B fails, which resources are blocked?
4. What is the minimum number of sequential "waves" needed to apply all 5 resources?

---

### Exercise 3 — Hard: Tool Comparison Research

Research OpenTofu and one other IaC tool of your choice (Pulumi, AWS CDK, Crossplane, or Ansible). Write a one-page comparison covering:

1. **Execution model**: How does each tool determine what changes to make?
2. **State management**: Does the tool track state? Where is it stored?
3. **Language**: What languages are supported? What are the tradeoffs?
4. **Provider ecosystem**: How large is each tool's provider ecosystem?
5. **Use case fit**: When would you choose one over the other?
6. **Licence and governance**: What are the licensing implications for your organisation?

Your comparison should be specific and cite sources.

↑ [Back to Table of Contents](#table-of-contents)

---

## Further Reading

- [OpenTofu Official Documentation](https://opentofu.org/docs/) — Start here for the authoritative reference
- [OpenTofu GitHub Repository](https://github.com/opentofu/opentofu) — Source code, issues, RFCs, and release notes
- [The OpenTofu Fork Announcement](https://opentofu.org/blog/the-opentofu-manifesto/) — Background on why the fork happened
- [Linux Foundation — OpenTofu Project](https://www.linuxfoundation.org/press/linux-foundation-joins-opentofu) — Governance structure
- [HashiCorp BSL Licence FAQ](https://www.hashicorp.com/license-faq) — HashiCorp's perspective (for context)
- [IaC Best Practices — Spacelift Blog](https://spacelift.io/blog/infrastructure-as-code) — Broader IaC patterns and practices

↑ [Back to Table of Contents](#table-of-contents)

---

## Summary

| Concept | Key Takeaway |
|---|---|
| IaC | Manage infrastructure through version-controlled configuration files |
| Declarative | Describe desired state; OpenTofu figures out the steps |
| Idempotency | Running apply twice makes no changes the second time |
| OpenTofu vs Terraform | Same HCL, different governance and licence; OpenTofu adds state encryption |
| DAG | OpenTofu builds a dependency graph and walks it in parallel |
| Plan/Apply | Plan = preview (read-only); Apply = execute changes |
| HCL | Human-readable config language; files loaded from working directory |

↑ [Back to Table of Contents](#table-of-contents)

---

## Next Module →

**[Module 02 — Installation & Setup](../02-installation/02-installation.md)**

Install OpenTofu, set up your editor, learn about version managers and environment variables.


---

<sub>© 2026 UncleJS & Course OpenTofu contributors — licensed under [CC BY-NC-SA 4.0](../../LICENSE).<br>
You may share and adapt this material for non-commercial purposes with attribution.<br>
SPDX-License-Identifier: CC-BY-NC-SA-4.0</sub>