# OpenTofu Course — Glossary of Terms

<!-- SPDX-License-Identifier: CC-BY-NC-SA-4.0 -->

[![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)
[![Terms](https://img.shields.io/badge/Terms-60%2B-blue)](./GLOSSARY.md)

A plain-English reference for every term used across this course. Each entry includes a definition and a cross-link to the module where the concept is taught in depth.

---

## Table of Contents

- [A](#a)
- [B](#b)
- [C](#c)
- [D](#d)
- [E](#e)
- [F](#f)
- [G](#g)
- [H](#h)
- [I](#i)
- [J](#j)
- [K](#k)
- [L](#l)
- [M](#m)
- [N](#n)
- [O](#o)
- [P](#p)
- [R](#r)
- [S](#s)
- [T](#t)
- [U](#u)
- [V](#v)
- [W](#w)

→ [Back to Course README](./README.md)

---

## A

### Actual State
The real-world condition of your infrastructure as it currently exists — what the provider reports when OpenTofu reads it. Contrasted with **desired state**. When actual state diverges from desired state, **drift** has occurred.
→ See [Module 05 — State Management](./modules/05-state-management/)

### Apply
The OpenTofu command (`tofu apply`) that executes the changes described in a **plan**. Apply calls the provider's Create, Update, or Delete APIs to reconcile actual state with desired state.
→ See [Module 01 — Introduction](./modules/01-introduction/)

### Argument
A named value assigned within a block in HCL. For example, `filename = "hello.txt"` is an argument. Arguments are leaf-level values inside a block, as opposed to nested blocks.
→ See [Module 03 — Providers & Resources](./modules/03-providers-and-resources/)

### Attribute
A value that a resource or data source exposes after it has been created or read. Attributes can be referenced by other resources: `local_file.example.filename`. Contrast with **argument** (what you set) vs **attribute** (what you read back).
→ See [Module 03 — Providers & Resources](./modules/03-providers-and-resources/)

### Auto-approve
A flag (`tofu apply -auto-approve`) that skips the interactive confirmation prompt. Common in CI/CD pipelines where human approval is handled at the pipeline gate level.
→ See [Module 10 — CI/CD Integration](./modules/10-cicd-integration/)

↑ [Back to Table of Contents](#table-of-contents)

---

## B

### Backend
The system OpenTofu uses to store **state** and optionally execute remote operations. A backend can be local (a file on disk) or remote (S3, GCS, HTTP, etc.). All backends provide state storage; some also provide state locking.
→ See [Module 09 — Backends & Remote State](./modules/09-backends-and-remote-state/)

### Block
The fundamental structural unit of HCL. A block has a type, optional labels, and a body enclosed in `{ }`. Examples: `resource "local_file" "example" { ... }`, `variable "name" { ... }`.
→ See [Module 03 — Providers & Resources](./modules/03-providers-and-resources/)

### Backend Configuration
The `backend { }` block inside a `terraform { }` block that tells OpenTofu where to store state. Can be partially supplied via `-backend-config` flags for secret separation.
→ See [Module 09 — Backends & Remote State](./modules/09-backends-and-remote-state/)

↑ [Back to Table of Contents](#table-of-contents)

---

## C

### `can()`
A built-in function that evaluates an expression and returns `true` if it succeeds without error, or `false` if it would produce an error. Used for defensive expression writing alongside `try()`.
→ See [Module 08 — Functions & Expressions](./modules/08-functions-and-expressions/)

### `check` Block
An OpenTofu block (1.5+) that runs custom assertions during plan and apply. Unlike `precondition`, a failing `check` block produces a warning rather than an error, making it suitable for soft invariants.
→ See [Module 12 — Advanced Patterns](./modules/12-advanced-patterns/)

### Child Module
Any module that is called by another module using a `module` block. The calling module is the **root module** (or parent). Child modules receive inputs via variables and expose outputs.
→ See [Module 06 — Modules](./modules/06-modules/)

### Configuration Drift
See **Drift**.

### Contract Test
A test that verifies a module's external interface (inputs and outputs) does not change in a breaking way. Ensures callers of a module are not silently broken by internal changes.
→ See [Module 11 — Testing](./modules/11-testing/)

### `count`
A meta-argument that creates multiple instances of a resource or module based on a numeric value. Each instance is addressed as `resource_type.name[index]`. For map-keyed instances, prefer `for_each`.
→ See [Module 03 — Providers & Resources](./modules/03-providers-and-resources/)

↑ [Back to Table of Contents](#table-of-contents)

---

## D

### DAG (Directed Acyclic Graph)
The internal data structure OpenTofu builds to represent all resources and their dependencies. "Directed" means dependencies have direction (A depends on B). "Acyclic" means there are no circular dependencies. OpenTofu walks the DAG to determine the order and parallelism of operations.
→ See [Module 01 — Introduction](./modules/01-introduction/)

### Data Source
A read-only resource that queries existing infrastructure or external data without managing it. Declared with the `data` block. Refreshed during every plan.
→ See [Module 03 — Providers & Resources](./modules/03-providers-and-resources/)

### Declarative
A style of programming or configuration where you describe **what** the end state should be, not **how** to get there. OpenTofu is declarative — you write the desired state in HCL and OpenTofu figures out the steps.
→ See [Module 01 — Introduction](./modules/01-introduction/)

### `depends_on`
A meta-argument that creates an explicit dependency between resources, even when no attribute reference exists. Use sparingly; implicit dependencies via attribute references are preferred.
→ See [Module 03 — Providers & Resources](./modules/03-providers-and-resources/)

### Desired State
The infrastructure configuration you have declared in your `.tf` files — what you want the world to look like. OpenTofu's job is to reconcile **actual state** with desired state.
→ See [Module 05 — State Management](./modules/05-state-management/)

### Destroy
The OpenTofu command (`tofu destroy`) that removes all resources managed by the current configuration from the real world and clears them from state.
→ See [Module 01 — Introduction](./modules/01-introduction/)

### Dynamic Block
An HCL construct that generates repeated nested blocks programmatically from a collection value. Useful when the number of nested blocks is variable, such as multiple ingress rules.
→ See [Module 08 — Functions & Expressions](./modules/08-functions-and-expressions/)

### Drift
The condition where the actual state of infrastructure differs from the desired state recorded in OpenTofu's state file. Drift is caused by out-of-band changes (manual edits, other tools, provider-side changes).
→ See [Module 05 — State Management](./modules/05-state-management/)

↑ [Back to Table of Contents](#table-of-contents)

---

## E

### Enhanced Backend
A backend that provides both state storage and remote operation execution (running plan/apply on a remote server). The Terraform Cloud / HCP Terraform backend is the canonical example.
→ See [Module 09 — Backends & Remote State](./modules/09-backends-and-remote-state/)

### Ephemeral Resource
A resource type (OpenTofu 1.10+) whose value exists only for the duration of a single plan/apply cycle and is never persisted to state. Designed for short-lived credentials and dynamic secrets.
→ See [Module 12 — Advanced Patterns](./modules/12-advanced-patterns/)

### Expression
A combination of values, references, and functions that evaluates to a single value. Expressions appear as argument values in HCL. Examples: `"hello-${var.name}"`, `length(var.items) > 0 ? "yes" : "no"`.
→ See [Module 08 — Functions & Expressions](./modules/08-functions-and-expressions/)

↑ [Back to Table of Contents](#table-of-contents)

---

## F

### `for` Expression
An HCL expression that transforms a list or map into a new list or map. Example: `[for s in var.names : upper(s)]`. Supports filtering with an `if` clause.
→ See [Module 08 — Functions & Expressions](./modules/08-functions-and-expressions/)

### `for_each`
A meta-argument that creates one resource or module instance per element of a map or set. Each instance is addressed by its key: `resource_type.name["key"]`. Preferred over `count` for named instances.
→ See [Module 03 — Providers & Resources](./modules/03-providers-and-resources/)

### Force-Unlock
The `tofu force-unlock <lock-id>` command that manually removes a state lock when a previous run crashed without releasing it. Use with extreme caution — only when you are certain no other process is modifying state.
→ See [Module 14 — Troubleshooting](./modules/14-troubleshooting/)

↑ [Back to Table of Contents](#table-of-contents)

---

## G

### GitOps
An operational model where infrastructure configuration is stored in Git and changes to infrastructure are driven by Git events (pull requests, merges). OpenTofu plan runs on PR; apply runs on merge to main.
→ See [Module 10 — CI/CD Integration](./modules/10-cicd-integration/)

### gRPC
The remote procedure call protocol used for communication between the OpenTofu core engine and provider plugin binaries. Each provider runs as a separate process and exposes a gRPC server.
→ See [Module 01 — Introduction](./modules/01-introduction/)

↑ [Back to Table of Contents](#table-of-contents)

---

## H

### HCL (HashiCorp Configuration Language)
The declarative configuration language used to write OpenTofu configurations. HCL is human-readable, supports expressions and functions, and maps closely to JSON (it can be serialised to/from JSON).
→ See [Module 01 — Introduction](./modules/01-introduction/)

### Heredoc
A multi-line string literal in HCL using the `<<-EOF ... EOF` syntax. The `<<-` variant strips leading whitespace, enabling indented multi-line strings.
→ See [Module 08 — Functions & Expressions](./modules/08-functions-and-expressions/)

↑ [Back to Table of Contents](#table-of-contents)

---

## I

### Idempotency
The property of an operation that produces the same result regardless of how many times it is run. A correctly written OpenTofu configuration is idempotent: running `tofu apply` twice in a row makes no changes on the second run.
→ See [Module 01 — Introduction](./modules/01-introduction/)

### Import Block
An HCL block (OpenTofu 1.5+) that declaratively imports an existing real-world resource into OpenTofu state without requiring a CLI command. Replaces the imperative `tofu import` command for most use cases.
→ See [Module 12 — Advanced Patterns](./modules/12-advanced-patterns/)

### Init
The `tofu init` command that initialises a working directory: downloads provider plugins, sets up the backend, and installs module sources. Must be run before plan or apply.
→ See [Module 02 — Installation & Setup](./modules/02-installation/)

### Input Variable
A variable declared with a `variable` block that accepts values from outside the module — from `.tfvars` files, `-var` flags, environment variables, or the calling module.
→ See [Module 04 — Variables & Outputs](./modules/04-variables-and-outputs/)

↑ [Back to Table of Contents](#table-of-contents)

---

## J

### JSON (in OpenTofu context)
OpenTofu configurations can be written in JSON (`*.tf.json`) instead of HCL. This is useful for programmatic generation. The `jsonencode()` and `jsondecode()` functions convert between HCL values and JSON strings.
→ See [Module 08 — Functions & Expressions](./modules/08-functions-and-expressions/)

↑ [Back to Table of Contents](#table-of-contents)

---

## K

### Keeper
An argument on `random_*` resources that controls when a random value is regenerated. When a keeper value changes, the random resource is destroyed and recreated, producing a new random value.
→ See [Module 03 — Providers & Resources](./modules/03-providers-and-resources/)

↑ [Back to Table of Contents](#table-of-contents)

---

## L

### Label
An identifier that follows a block type in HCL. `resource "local_file" "example"` has two labels: `"local_file"` (type) and `"example"` (name). Labels provide the addressing path for references.
→ See [Module 03 — Providers & Resources](./modules/03-providers-and-resources/)

### `lifecycle` Block
A meta-argument block inside a resource that customises how OpenTofu manages the resource's create/update/delete cycle. Options: `create_before_destroy`, `prevent_destroy`, `ignore_changes`, `replace_triggered_by`.
→ See [Module 03 — Providers & Resources](./modules/03-providers-and-resources/)

### Lineage
A UUID stored in the state file that uniquely identifies a state's origin. OpenTofu checks lineage to prevent accidentally merging state from two unrelated configurations.
→ See [Module 05 — State Management](./modules/05-state-management/)

### Lock File (`.terraform.lock.hcl`)
A file generated by `tofu init` that records the exact provider versions and checksums selected. Should be committed to version control to ensure all team members and CI use identical provider versions.
→ See [Module 02 — Installation & Setup](./modules/02-installation/)

### Local Value (`locals`)
A named computed value defined in a `locals` block, scoped to the current module. Locals reduce repetition and name complex expressions. They cannot be overridden from outside the module.
→ See [Module 04 — Variables & Outputs](./modules/04-variables-and-outputs/)

↑ [Back to Table of Contents](#table-of-contents)

---

## M

### Managed Resource
A resource fully managed by OpenTofu — its lifecycle (create, read, update, delete) is handled by OpenTofu through the provider. Declared with the `resource` block.
→ See [Module 03 — Providers & Resources](./modules/03-providers-and-resources/)

### Meta-argument
A special argument accepted by all resources and modules regardless of provider. The meta-arguments are: `depends_on`, `count`, `for_each`, `provider`, and `lifecycle`.
→ See [Module 03 — Providers & Resources](./modules/03-providers-and-resources/)

### Module
A directory of `.tf` files that are treated as a single unit. Modules accept inputs (variables) and expose outputs. They are the primary reuse and encapsulation mechanism in OpenTofu.
→ See [Module 06 — Modules](./modules/06-modules/)

### Module Registry
A versioned repository of reusable modules. OpenTofu's default public registry is at `registry.opentofu.org`. Module sources from the registry use the format `namespace/module-name/provider`.
→ See [Module 06 — Modules](./modules/06-modules/)

### `moved` Block
An HCL block that records a resource or module rename/move, allowing OpenTofu to update state without destroying and recreating the resource. Essential for safe refactoring.
→ See [Module 12 — Advanced Patterns](./modules/12-advanced-patterns/)

↑ [Back to Table of Contents](#table-of-contents)

---

## N

### Null Provider
The `hashicorp/null` provider that supplies `null_resource` — a resource with no real-world counterpart. Used to trigger arbitrary `local-exec` provisioners or model dependencies between non-resource actions.
→ See [Module 03 — Providers & Resources](./modules/03-providers-and-resources/)

↑ [Back to Table of Contents](#table-of-contents)

---

## O

### OpenTofu
An open-source Infrastructure as Code tool forked from Terraform in 2023 following HashiCorp's licence change to BSL. Maintained by the Linux Foundation. Uses HCL for configuration and a provider plugin architecture.
→ See [Module 01 — Introduction](./modules/01-introduction/)

### Output Value
A value declared with an `output` block that is exposed by a module after apply. Root module outputs are printed to the terminal. Child module outputs are accessible to the calling module.
→ See [Module 04 — Variables & Outputs](./modules/04-variables-and-outputs/)

↑ [Back to Table of Contents](#table-of-contents)

---

## P

### Partial Configuration
A backend configuration pattern where sensitive values (credentials, bucket names) are omitted from the `backend {}` block and supplied at `tofu init` time via `-backend-config` flags or files.
→ See [Module 09 — Backends & Remote State](./modules/09-backends-and-remote-state/)

### Plan
The `tofu plan` command that calculates the difference between desired state (HCL) and actual state (provider + state file), and produces a human-readable and machine-readable description of changes. No real-world changes are made.
→ See [Module 01 — Introduction](./modules/01-introduction/)

### Plan Artifact
A binary file produced by `tofu plan -out=plan.bin` that captures the exact planned changes. When passed to `tofu apply plan.bin`, OpenTofu executes exactly those changes — no re-planning occurs. Critical for CI/CD pipelines.
→ See [Module 10 — CI/CD Integration](./modules/10-cicd-integration/)

### Plugin Binary
The executable file that implements a provider. OpenTofu downloads provider plugin binaries to `.terraform/providers/` during `init`. Each binary speaks the gRPC provider protocol.
→ See [Module 01 — Introduction](./modules/01-introduction/)

### `postcondition`
A lifecycle condition checked after a resource is created or updated. If the condition fails, the apply is halted with an error. Used to verify that a resource was created with the expected attributes.
→ See [Module 12 — Advanced Patterns](./modules/12-advanced-patterns/)

### `precondition`
A lifecycle condition checked before a resource is created or updated. If the condition fails, the plan is halted with an error. Used to validate inputs and guard against dangerous configurations.
→ See [Module 12 — Advanced Patterns](./modules/12-advanced-patterns/)

### Provider
A plugin that implements the API integration for a specific platform (AWS, GCP, GitHub, local filesystem, etc.). Providers declare resources and data sources. Configured with a `provider` block.
→ See [Module 03 — Providers & Resources](./modules/03-providers-and-resources/)

### Provider Alias
A second (or third) configuration for the same provider, identified by an `alias` argument. Used when you need to manage resources in multiple regions, accounts, or environments within the same configuration.
→ See [Module 03 — Providers & Resources](./modules/03-providers-and-resources/)

### Provider Protocol
The versioned gRPC interface between OpenTofu core and provider plugin binaries. The current protocol version is 6 (plugin framework) and 5 (SDK v2). OpenTofu negotiates the protocol version at init time.
→ See [Module 01 — Introduction](./modules/01-introduction/)

↑ [Back to Table of Contents](#table-of-contents)

---

## R

### Reconciliation
The process of comparing desired state with actual state and making the changes necessary to bring actual state into alignment. What `tofu apply` does.
→ See [Module 01 — Introduction](./modules/01-introduction/)

### `refresh`
The process of querying the provider for the current real-world state of each managed resource and updating the state file. Runs automatically before every plan. Can be run standalone with `tofu apply -refresh-only`.
→ See [Module 05 — State Management](./modules/05-state-management/)

### Remote State
State stored in a remote backend (S3, GCS, HTTP, etc.) rather than on the local filesystem. Enables team collaboration, state locking, and sharing outputs between configurations via `terraform_remote_state`.
→ See [Module 09 — Backends & Remote State](./modules/09-backends-and-remote-state/)

### `removed` Block
An HCL block (OpenTofu 1.7+) that removes a resource from state without destroying it in the real world (`destroy = false`). The inverse of `import`.
→ See [Module 12 — Advanced Patterns](./modules/12-advanced-patterns/)

### Resource
The primary building block of OpenTofu configurations. A resource represents a single real-world infrastructure object (a file, a virtual machine, a DNS record). Declared with the `resource` block.
→ See [Module 03 — Providers & Resources](./modules/03-providers-and-resources/)

### Root Module
The top-level module in a configuration — the directory where you run `tofu init` and `tofu apply`. It may call child modules. Every OpenTofu configuration has exactly one root module.
→ See [Module 06 — Modules](./modules/06-modules/)

↑ [Back to Table of Contents](#table-of-contents)

---

## S

### Sensitive Value
A value marked `sensitive = true` in a variable or output declaration. OpenTofu redacts sensitive values from plan/apply output (`(sensitive value)`). **Important:** sensitive values are still stored in plaintext in the state file.
→ See [Module 04 — Variables & Outputs](./modules/04-variables-and-outputs/)

### Serial Number
An integer in the state file that increments on every successful apply. OpenTofu uses the serial number to detect concurrent modifications and prevent state corruption.
→ See [Module 05 — State Management](./modules/05-state-management/)

### Speculative Plan
A plan run that does not produce an artifact and cannot be applied — used for informational purposes, such as showing a PR author what changes their code would make. Common in CI/CD pull request workflows.
→ See [Module 10 — CI/CD Integration](./modules/10-cicd-integration/)

### Splat Expression
An HCL shorthand for extracting a single attribute from all instances of a resource created with `count`. `aws_instance.example[*].id` is equivalent to `[for o in aws_instance.example : o.id]`.
→ See [Module 08 — Functions & Expressions](./modules/08-functions-and-expressions/)

### State
A JSON file (`terraform.tfstate`) that records the current known state of all resources managed by OpenTofu. State is the mapping between your HCL resource addresses and real-world resource IDs.
→ See [Module 05 — State Management](./modules/05-state-management/)

### State Backend
See **Backend**.

### State Lock
A mechanism that prevents concurrent `tofu apply` or `tofu state` operations from corrupting state. Local backends use a lock file; remote backends use database rows (e.g., DynamoDB) or object metadata.
→ See [Module 05 — State Management](./modules/05-state-management/)

↑ [Back to Table of Contents](#table-of-contents)

---

## T

### `templatefile()`
A built-in function that reads a file and renders it as a template, substituting variables from a provided map. The template uses the same expression syntax as HCL. Ideal for generating config files and scripts.
→ See [Module 08 — Functions & Expressions](./modules/08-functions-and-expressions/)

### `tofu console`
An interactive REPL (Read-Eval-Print Loop) that evaluates HCL expressions against the current configuration and state. Invaluable for debugging complex expressions before adding them to your configuration.
→ See [Module 08 — Functions & Expressions](./modules/08-functions-and-expressions/)

### `tofu test`
The native OpenTofu testing framework (1.6+). Test files use the `.tftest.hcl` extension and contain `run` blocks with `assert` blocks. Supports `mock_provider` for unit testing without applying real resources.
→ See [Module 11 — Testing](./modules/11-testing/)

### `try()`
A built-in function that evaluates a sequence of expressions and returns the first one that does not produce an error. Used for optional attribute access and defensive expression patterns.
→ See [Module 08 — Functions & Expressions](./modules/08-functions-and-expressions/)

↑ [Back to Table of Contents](#table-of-contents)

---

## U

### Unknown Value
A value that is known to exist but whose actual content cannot be determined until apply time (e.g., the ID of a resource that hasn't been created yet). Shown as `(known after apply)` in plan output. Cannot be used in `count` or `for_each`.
→ See [Module 03 — Providers & Resources](./modules/03-providers-and-resources/)

↑ [Back to Table of Contents](#table-of-contents)

---

## V

### Validate
The `tofu validate` command that checks a configuration for syntactic correctness and type safety without contacting any provider or reading state. A fast, offline check.
→ See [Module 13 — Healthcheck](./modules/13-healthcheck/)

### Variable File (`.tfvars`)
A file containing variable assignments in HCL (`name = "value"`) or JSON (`.tfvars.json`). `terraform.tfvars` and `*.auto.tfvars` are loaded automatically. Others must be specified with `-var-file`.
→ See [Module 04 — Variables & Outputs](./modules/04-variables-and-outputs/)

### Version Constraint
A string expression that restricts which versions of a provider or OpenTofu binary are acceptable. Uses semver operators: `=`, `!=`, `>`, `>=`, `<`, `<=`, `~>` (pessimistic constraint operator).
→ See [Module 02 — Installation & Setup](./modules/02-installation/)

↑ [Back to Table of Contents](#table-of-contents)

---

## W

### Workspace
A named slice of state within a single backend configuration. Multiple workspaces share the same configuration but have independent state files. The default workspace is named `default`. Accessible via `terraform.workspace`.
→ See [Module 07 — Workspaces](./modules/07-workspaces/)

### Working Directory
The directory containing the root module's `.tf` files — where you run `tofu init`, `tofu plan`, and `tofu apply`. OpenTofu loads all `.tf` and `.tf.json` files in this directory.
→ See [Module 02 — Installation & Setup](./modules/02-installation/)

↑ [Back to Table of Contents](#table-of-contents)

---

→ [Back to Course README](./README.md)
