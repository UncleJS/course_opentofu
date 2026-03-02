# ============================================================
# tests/basic.tftest.hcl
#
# Basic test suite for modules/11-testing/examples/
# Covers: plan validation, apply + output assertions, and
# negative tests using expect_failures.
# ============================================================

# Variable defaults applied to ALL run blocks in this file
variables {
  project_name = "test-project"
  environment  = "dev"
  output_dir   = "/tmp/tofu-test-module11"
  file_count   = 2
}

# ── Test 1: plan succeeds with default variables ──────────────────────────
run "plan_succeeds_with_defaults" {
  command = plan

  assert {
    condition     = var.project_name == "test-project"
    error_message = "project_name variable should be 'test-project'"
  }

  assert {
    condition     = var.environment == "dev"
    error_message = "environment variable should be 'dev'"
  }
}

# ── Test 2: apply creates the correct number of service files ─────────────
run "creates_correct_file_count" {
  command = apply

  assert {
    condition     = output.service_count == 2
    error_message = "expected 2 service files, got ${output.service_count}"
  }

  assert {
    condition     = length(output.service_paths) == 2
    error_message = "service_paths map should have exactly 2 entries"
  }
}

# ── Test 3: project_id is a non-empty hex string ──────────────────────────
run "project_id_is_valid_hex" {
  command = apply

  assert {
    condition     = length(output.project_id) > 0
    error_message = "project_id must not be empty"
  }

  assert {
    condition     = can(regex("^[a-f0-9]+$", output.project_id))
    error_message = "project_id must be a lowercase hex string, got: ${output.project_id}"
  }
}

# ── Test 4: environment is reflected in output ────────────────────────────
run "environment_output_matches_variable" {
  command = apply

  variables {
    environment = "staging"
  }

  assert {
    condition     = output.environment == "staging"
    error_message = "output.environment should equal the input variable"
  }
}

# ── Test 5: negative — invalid environment value triggers validation ──────
run "rejects_invalid_environment" {
  command = plan

  variables {
    environment = "production"  # not in the allowed list
  }

  expect_failures = [var.environment]
}

# ── Test 6: negative — project_name too short triggers validation ─────────
run "rejects_short_project_name" {
  command = plan

  variables {
    project_name = "ab"  # fewer than 3 characters
  }

  expect_failures = [var.project_name]
}

# ── Test 7: negative — file_count out of range ────────────────────────────
run "rejects_file_count_zero" {
  command = plan

  variables {
    file_count = 0  # minimum is 1
  }

  expect_failures = [var.file_count]
}
