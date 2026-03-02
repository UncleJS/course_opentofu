<!--
SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->

# Module 11 — Testing

[![Module](https://img.shields.io/badge/module-11%20of%2014-blue?style=flat-square)](../..)
[![Difficulty](https://img.shields.io/badge/difficulty-Advanced-red?style=flat-square)](../..)
[![Time](https://img.shields.io/badge/time-90%20min-lightgrey?style=flat-square)](../..)
[![License](https://img.shields.io/badge/license-CC%20BY--NC--SA%204.0-green?style=flat-square)](../../LICENSE)

> Write real tests for your OpenTofu modules using the native `tofu test` framework — no external tools required.

---

## Table of Contents

1. [Why Test Infrastructure Code?](#1-why-test-infrastructure-code)
2. [OpenTofu Testing Concepts](#2-opentofu-testing-concepts)
3. [Test File Anatomy](#3-test-file-anatomy)
4. [Writing Your First Test](#4-writing-your-first-test)
5. [Variables & Mocking in Tests](#5-variables--mocking-in-tests)
6. [Test Runs & Assertions](#6-test-runs--assertions)
7. [Module Testing Patterns](#7-module-testing-patterns)
8. [Testing in CI](#8-testing-in-ci)
9. [Exercises](#9-exercises)
10. [Further Reading](#10-further-reading)

---

## 1. Why Test Infrastructure Code?

Infrastructure is code — and like all code it has bugs:

| Bug type | Example | Caught by |
|---|---|---|
| Syntax error | Missing `}` | `tofu validate` |
| Logic error | Wrong output reference | `tofu test` |
| Contract violation | Module output is wrong type | `tofu test` |
| Regression | Refactor breaks existing behaviour | `tofu test` |
| Policy violation | Resource missing required tag | `tofu test` + OPA/Sentinel |

> **Under the hood:** `tofu test` was introduced in OpenTofu 1.6 (ported from Terraform 1.6). It provisions real infrastructure, evaluates assertions, then destroys everything in a single command — making it safe to run in CI. Each `.tftest.hcl` file is a test suite; each `run` block is a test case.

[↑ Back to Table of Contents](#table-of-contents)

---

## 2. OpenTofu Testing Concepts

### Key terms

| Term | Meaning |
|---|---|
| **Test suite** | A `.tftest.hcl` file; groups related test cases |
| **`run` block** | A single test case; maps to one plan/apply cycle |
| **`assert` block** | A boolean condition + error message |
| **`variables` block** | Input overrides for a specific `run` block |
| **`mock_provider` block** | Replace a real provider with a fake; no real resources created |
| **`command`** | `plan` (no apply) or `apply` (default); apply tests are slower but test real state |

### Test lifecycle

```
tofu test
  │
  ├── for each .tftest.hcl file:
  │     ├── for each run block:
  │     │     ├── tofu plan  (always)
  │     │     ├── tofu apply (if command = apply, the default)
  │     │     ├── evaluate assert blocks
  │     │     └── continue or fail
  │     └── tofu destroy (cleanup after all runs in the file)
  └── report pass/fail per assert
```

> **Under the hood:** OpenTofu runs each `run` block sequentially within a file. The state from a prior `run` block is available to subsequent `run` blocks in the same file — this allows multi-step scenarios (create → modify → verify).

[↑ Back to Table of Contents](#table-of-contents)

---

## 3. Test File Anatomy

```hcl
# tests/my_module.tftest.hcl

# Optional: override provider configuration for testing
provider "local" {}

# Optional: variable defaults for ALL runs in this file
variables {
  project_name = "test-project"
  environment  = "dev"
}

# ── Test case 1: plan only (fast, no real resources) ─────────────────────
run "plan_succeeds_with_defaults" {
  command = plan   # don't apply — just validate the plan

  assert {
    condition     = output.project_id != ""
    error_message = "project_id output must not be empty"
  }
}

# ── Test case 2: apply and verify real state ──────────────────────────────
run "creates_expected_files" {
  command = apply  # default; can be omitted

  variables {
    resource_count = 2   # override just for this run
  }

  assert {
    condition     = length(output.config_file_paths) == 2
    error_message = "expected 2 config files, got ${length(output.config_file_paths)}"
  }

  assert {
    condition     = output.environment == "dev"
    error_message = "environment output should be 'dev'"
  }
}

# ── Test case 3: negative test — validation should reject bad input ───────
run "rejects_invalid_environment" {
  command = plan

  variables {
    environment = "production"   # invalid — only dev/staging/prod allowed
  }

  expect_failures = [
    var.environment,   # this variable's validation block should fire
  ]
}
```

[↑ Back to Table of Contents](#table-of-contents)

---

## 4. Writing Your First Test

Assuming you are testing the Module 05 example configuration:

```bash
cd modules/05-state-management/examples
tofu init

# Run all tests (discovers *.tftest.hcl automatically)
tofu test

# Run a specific test file
tofu test -filter=tests/state_management.tftest.hcl

# Verbose output (shows each assert result)
tofu test -verbose
```

Expected output:

```
  run "plan_succeeds" ... pass
  run "creates_files_with_correct_count" ... pass
  run "rejects_invalid_environment" ... pass

Success! 3 passed, 0 failed.
```

[↑ Back to Table of Contents](#table-of-contents)

---

## 5. Variables & Mocking in Tests

### Variable overrides

Each `run` block can override any input variable:

```hcl
run "staging_environment" {
  variables {
    environment    = "staging"
    resource_count = 5
    output_dir     = "/tmp/test-staging"
  }

  assert {
    condition     = output.environment == "staging"
    error_message = "environment should be staging"
  }
}
```

### Mock providers (OpenTofu 1.7+)

Mock providers let you test module logic without provisioning real infrastructure. The provider returns predictable fake values:

```hcl
mock_provider "aws" {
  mock_resource "aws_s3_bucket" {
    defaults = {
      id     = "mock-bucket-id"
      arn    = "arn:aws:s3:::mock-bucket"
      region = "us-east-1"
    }
  }
}

run "s3_bucket_name_format" {
  command = plan

  assert {
    condition     = aws_s3_bucket.main.id == "mock-bucket-id"
    error_message = "bucket ID should match mock"
  }
}
```

> **Under the hood:** Mock providers implement the same gRPC provider protocol as real providers, but return hardcoded values from the `defaults` map instead of calling real APIs. This makes plan-only tests milliseconds fast.

[↑ Back to Table of Contents](#table-of-contents)

---

## 6. Test Runs & Assertions

### Assertion expressions

Any OpenTofu expression that returns `bool` is valid:

```hcl
# String checks
assert {
  condition     = startswith(output.project_id, "proj-")
  error_message = "project_id must start with 'proj-'"
}

# Collection checks
assert {
  condition     = length(output.config_file_paths) > 0
  error_message = "at least one config file must be created"
}

# Type checks via can()
assert {
  condition     = can(tostring(output.project_id))
  error_message = "project_id must be convertible to string"
}

# Regex
assert {
  condition     = can(regex("^[a-f0-9]{12}$", output.project_id))
  error_message = "project_id must be a 12-char hex string"
}
```

### `expect_failures`

Use `expect_failures` to assert that a validation **should** fail:

```hcl
run "count_below_minimum" {
  command = plan

  variables { resource_count = 0 }

  expect_failures = [var.resource_count]
}
```

> If the plan succeeds (i.e. validation does NOT fail), OpenTofu marks the test as **failed** — because you declared you expected a failure.

[↑ Back to Table of Contents](#table-of-contents)

---

## 7. Module Testing Patterns

### Unit test: test a child module in isolation

```hcl
# tests/file_generator_unit.tftest.hcl
# Target: modules/06-modules/examples/file-generator/

run "generates_correct_file_count" {
  variables {
    files = {
      "config-a" = { content = "aaa", permissions = "0644" }
      "config-b" = { content = "bbb", permissions = "0644" }
    }
    output_dir = "/tmp/test-unit"
  }

  assert {
    condition     = length(output.file_paths) == 2
    error_message = "should generate exactly 2 files"
  }
}
```

### Integration test: test the root module calling the child

```hcl
# tests/file_generator_integration.tftest.hcl

run "root_module_integration" {
  assert {
    condition     = output.total_files_created >= 1
    error_message = "root module must create at least one file"
  }
}
```

### Contract test: verify module outputs match a documented interface

```hcl
run "output_contract" {
  command = plan

  assert {
    condition     = can(output.project_id)
    error_message = "project_id output must exist"
  }

  assert {
    condition     = can(output.config_file_paths)
    error_message = "config_file_paths output must exist"
  }
}
```

[↑ Back to Table of Contents](#table-of-contents)

---

## 8. Testing in CI

Add a test stage before the plan stage:

```yaml
# GitHub Actions addition to Module 10's workflow
test:
  name: Test
  runs-on: ubuntu-latest
  needs: [validate]
  steps:
    - uses: actions/checkout@v4
    - uses: opentofu/setup-opentofu@v1
      with:
        tofu_version: "1.8.0"
    - run: tofu init
      working-directory: modules/11-testing/examples
    - run: tofu test -verbose
      working-directory: modules/11-testing/examples
```

### Test coverage targets

| Target | What to test |
|---|---|
| Every reusable module | At minimum: plan succeeds, required outputs exist |
| Variable validations | One `expect_failures` test per `validation` block |
| Complex locals/expressions | `plan`-only tests are fast enough to run on every commit |
| Full apply | Run nightly in CI (slower; provisions real infra) |

[↑ Back to Table of Contents](#table-of-contents)

---

## 9. Exercises

### Exercise 1 — Easy: Run the example tests

```bash
cd modules/11-testing/examples
tofu init
tofu test -verbose
```

Observe: which assertions pass, which `run` blocks use `command = plan` vs apply.

**Challenge:** Add a fourth `run` block that verifies `output.environment` equals `"dev"`.

---

### Exercise 2 — Medium: Test a module from scratch

Write a test file for `modules/06-modules/examples/`:

```bash
mkdir -p modules/06-modules/examples/tests
# Create tests/root_module.tftest.hcl with at least 3 run blocks:
# 1. plan succeeds with defaults
# 2. output.total_files_created > 0 after apply
# 3. expect_failures for a bad variable value
tofu test -verbose
```

---

### Exercise 3 — Hard: CI-style test pipeline

Write a shell script `run-all-tests.sh` that:

1. Loops over all modules that contain a `tests/` directory
2. Runs `tofu init && tofu test -verbose` in each
3. Collects pass/fail results
4. Exits non-zero if any module fails
5. Prints a summary table

```bash
chmod +x run-all-tests.sh
./run-all-tests.sh
```

[↑ Back to Table of Contents](#table-of-contents)

---

## 10. Further Reading

- [OpenTofu Test command reference](https://opentofu.org/docs/cli/commands/test/)
- [OpenTofu Test framework language spec](https://opentofu.org/docs/language/tests/)
- [Mock providers in OpenTofu 1.7](https://opentofu.org/docs/language/tests/#mocking)
- [Test-driven IaC with Terraform/OpenTofu (blog)](https://developer.hashicorp.com/terraform/tutorials/configuration-language/test)
- [Terratest — Go-based integration testing](https://terratest.gruntwork.io/)
- [Open Policy Agent (OPA) for policy testing](https://www.openpolicyagent.org/docs/latest/terraform/)

[↑ Back to Table of Contents](#table-of-contents)


---

<sub>© 2026 UncleJS & Course OpenTofu contributors — licensed under [CC BY-NC-SA 4.0](../../LICENSE).<br>
You may share and adapt this material for non-commercial purposes with attribution.<br>
SPDX-License-Identifier: CC-BY-NC-SA-4.0</sub>