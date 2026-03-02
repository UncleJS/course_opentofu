# ============================================================
# Module 05 — State Management: worked example
#
# What this configuration demonstrates
# ─────────────────────────────────────
#  1. How OpenTofu tracks resources in state (random_id, local_file)
#  2. Resource targeting  → tofu apply -target=local_file.config[0]
#  3. State inspection    → tofu state list / show / pull
#  4. State manipulation  → tofu state mv / tofu state rm
#  5. Drift simulation    → change a trigger value, re-run tofu plan
#  6. Taint/replace       → tofu apply -replace=null_resource.drifted
#
# All resources write to /tmp so nothing persists after a reboot.
# ============================================================

locals {
  # Build a map of config-file descriptors so we can use for_each
  configs = {
    for i in range(var.resource_count) :
    format("config-%02d", i + 1) => {
      index    = i + 1
      filename = format("%s/%s/config-%02d.json", var.output_dir, var.environment, i + 1)
    }
  }

  # A stable "build ID" that is baked into every config file.
  # Changing this forces a replacement of all config files — good
  # for demonstrating plan output that shows -/+ (destroy+create).
  build_metadata = {
    project     = var.project_name
    environment = var.environment
    generated   = "2026-01-01T00:00:00Z" # fixed so plans are deterministic
  }
}

# ── 1. Stable random IDs ─────────────────────────────────────────────────────
# random_id is created once and then STAYS in state even if other resources
# are removed.  Run `tofu state show random_id.project` to inspect it.

resource "random_id" "project" {
  byte_length = 8

  # keepers tie the ID to the project+env; changing either forces a new ID
  keepers = {
    project     = var.project_name
    environment = var.environment
  }
}

# ── 2. Output directory ───────────────────────────────────────────────────────
resource "local_file" "output_dir_marker" {
  filename        = "${var.output_dir}/${var.environment}/.keep"
  content         = "# managed by OpenTofu — do not delete\n"
  file_permission = "0644"
}

# ── 3. Numbered config files (for_each) ───────────────────────────────────────
# Run: tofu state list   → see each address
# Run: tofu state show 'local_file.config["config-01"]'

resource "local_file" "config" {
  for_each = local.configs

  filename        = each.value.filename
  file_permission = "0644"

  content = jsonencode(merge(local.build_metadata, {
    config_name = each.key
    index       = each.value.index
    project_id  = random_id.project.hex
  }))

  # Explicit dependency: the directory marker must exist first
  depends_on = [local_file.output_dir_marker]
}

# ── 4. Summary manifest ───────────────────────────────────────────────────────
# This file is re-generated on every apply; it records all config names.
# It is a good target for `tofu state rm` experiments — remove it from state
# then re-apply to see OpenTofu re-create it.

resource "local_file" "manifest" {
  filename        = "${var.output_dir}/${var.environment}/manifest.json"
  file_permission = "0644"

  content = jsonencode({
    project_id = random_id.project.hex
    configs    = keys(local.configs)
    count      = var.resource_count
  })

  depends_on = [local_file.output_dir_marker]
}

# ── 5. Drift simulation (optional) ───────────────────────────────────────────
# Enable with: tofu apply -var="drift_simulation=true"
#
# After the first apply, manually edit the state or change the trigger value
# to a different timestamp, then run `tofu plan` to observe drift detection.
#
# Real-world drift occurs when someone modifies infrastructure outside of
# OpenTofu (e.g. via the cloud console or a script).

resource "null_resource" "drifted" {
  count = var.drift_simulation ? 1 : 0

  triggers = {
    # Change this value between applies to simulate configuration drift.
    # Step 1: apply with drift_simulation=true  → state records "v1"
    # Step 2: change "v1" → "v2", run tofu plan → plan shows replacement
    version    = "v1"
    project_id = random_id.project.hex
  }

  provisioner "local-exec" {
    command = "echo '[drift-demo] null_resource.drifted triggered: version=${self.triggers.version}'"
  }
}

# ── 6. Checkpoint file ────────────────────────────────────────────────────────
# Written by a null_resource provisioner so we can demo `tofu state mv`
# (rename the resource in state without destroying/recreating it).
#
# Exercise: run `tofu state mv null_resource.checkpoint null_resource.renamed`
# then `tofu plan` — OpenTofu should show no changes.

resource "null_resource" "checkpoint" {
  triggers = {
    manifest_id = random_id.project.hex
    configs     = join(",", keys(local.configs))
  }

  provisioner "local-exec" {
    command = <<-SHELL
      echo '[checkpoint] apply complete' \
        >> ${var.output_dir}/${var.environment}/apply.log
    SHELL
  }

  depends_on = [local_file.manifest]
}
