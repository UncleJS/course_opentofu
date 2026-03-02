# ============================================================
# tests/advanced.tftest.hcl
#
# Advanced test cases: multi-step apply/modify/verify,
# tag propagation, and prod environment behaviour.
# ============================================================

variables {
  project_name = "advanced-test"
  output_dir   = "/tmp/tofu-test-module11-adv"
}

# ── Test 1: apply with minimum file_count ────────────────────────────────
run "minimum_file_count" {
  command = apply

  variables {
    environment = "dev"
    file_count  = 1
  }

  assert {
    condition     = output.service_count == 1
    error_message = "minimum file_count=1 should produce exactly 1 service file"
  }
}

# ── Test 2: scale up — apply with maximum file_count ─────────────────────
# This run block builds on the state from the previous run.
# OpenTofu will see a diff of +4 new service files.

run "maximum_file_count" {
  command = apply

  variables {
    environment = "dev"
    file_count  = 5
  }

  assert {
    condition     = output.service_count == 5
    error_message = "after scaling up, service_count should be 5"
  }

  assert {
    condition     = contains(keys(output.service_paths), "svc-05")
    error_message = "service_paths must include 'svc-05' at max count"
  }
}

# ── Test 3: custom tags are reflected in outputs ──────────────────────────
run "custom_tags_accepted" {
  command = plan   # plan only — we care about variable acceptance, not apply

  variables {
    environment = "dev"
    file_count  = 1
    tags = {
      owner = "security-team"
      tier  = "critical"
      cost  = "cc-1234"
    }
  }

  assert {
    condition     = var.tags["owner"] == "security-team"
    error_message = "custom tags should be accepted without error"
  }
}

# ── Test 4: prod environment is accepted ──────────────────────────────────
run "prod_environment_accepted" {
  command = plan

  variables {
    environment = "prod"
    file_count  = 1
  }

  assert {
    condition     = var.environment == "prod"
    error_message = "'prod' is a valid environment and should be accepted"
  }
}

# ── Test 5: service_paths keys follow the expected naming convention ───────
run "service_paths_naming_convention" {
  command = apply

  variables {
    environment = "staging"
    file_count  = 3
  }

  assert {
    condition = alltrue([
      for k in keys(output.service_paths) :
      can(regex("^svc-[0-9]{2}$", k))
    ])
    error_message = "all service_paths keys must match 'svc-NN' pattern"
  }
}
