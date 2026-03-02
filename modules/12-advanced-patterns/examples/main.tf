# ============================================================
# Module 12 — Advanced Patterns: worked example
#
# Demonstrates:
#  1. dynamic blocks (sections inside a config file)
#  2. lifecycle: create_before_destroy, precondition, postcondition
#  3. moved block (resource rename without destroy)
#  4. Complex object variable types
#  5. depends_on with explicit reasoning
#  6. DAG parallelism (multiple independent resources)
# ============================================================

resource "random_id" "project" {
  byte_length = 8
  keepers = {
    project     = var.project_name
    environment = var.environment
  }
}

# ── 1. Output directory ───────────────────────────────────────────────────
resource "local_file" "env_marker" {
  filename        = "${var.output_dir}/${var.environment}/.keep"
  content         = "# managed by OpenTofu\n"
  file_permission = "0644"
}

# ── 2. Dynamic sections demo ──────────────────────────────────────────────
# The locals block builds the list of sections that the dynamic block will
# expand.  Change var.section_count and run `tofu plan` to see the diff.

locals {
  sections = [
    for i in range(var.section_count) : {
      name    = "section-${i + 1}"
      enabled = i % 2 == 0  # even-indexed sections are enabled
      weight  = (i + 1) * 10
    }
  ]

  # Only enabled services
  active_services = {
    for name, svc in var.services :
    name => svc
    if svc.enabled
  }
}

# The 'content' of this file is built via a templatefile that loops over
# sections — demonstrating how dynamic data shapes resource content.
resource "local_file" "dynamic_config" {
  filename        = "${var.output_dir}/${var.environment}/dynamic-config.json"
  file_permission = "0644"

  content = jsonencode({
    project    = var.project_name
    project_id = random_id.project.hex
    sections   = local.sections
    services   = local.active_services
  })

  # ── lifecycle: create new file before destroying old one ─────────────
  lifecycle {
    create_before_destroy = true

    # precondition: prod deployments require an approver
    precondition {
      condition     = var.environment != "prod" || var.approved_by != ""
      error_message = "Production deployments require 'approved_by' to be set. Pass -var=\"approved_by=<name>\"."
    }

    # postcondition: file must actually exist after apply
    postcondition {
      condition     = fileexists(self.filename)
      error_message = "File ${self.filename} was not created — check output_dir permissions."
    }
  }

  depends_on = [local_file.env_marker]
}

# ── 3. Service manifest (complex object type) ─────────────────────────────
resource "local_file" "service_manifest" {
  filename        = "${var.output_dir}/${var.environment}/services.json"
  file_permission = "0644"

  content = jsonencode({
    active_services = {
      for name, svc in local.active_services : name => {
        port     = svc.port
        protocol = svc.protocol
        replicas = svc.replicas
        tags     = svc.tags
      }
    }
    disabled_services = [
      for name, svc in var.services :
      name
      if !svc.enabled
    ]
  })

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [local_file.env_marker]
}

# ── 4. moved block demo ───────────────────────────────────────────────────
# Step 1: Apply with this block commented out — creates local_file.legacy_report
# Step 2: Uncomment the moved block below, then run `tofu plan`
#         OpenTofu will show the rename without any destroy/create
# Step 3: Apply — state is updated, no file is touched on disk

resource "local_file" "legacy_report" {
  # NOTE: In a real refactor you would rename this to local_file.app_report
  # and add the moved block below. Left as-is so Exercise 2 has something to do.
  filename        = "${var.output_dir}/${var.environment}/report.json"
  file_permission = "0644"
  content = jsonencode({
    project_id   = random_id.project.hex
    environment  = var.environment
    section_count = var.section_count
  })

  depends_on = [local_file.env_marker]
}

# Uncomment to perform the rename:
# moved {
#   from = local_file.legacy_report
#   to   = local_file.app_report
# }

# ── 5. Null resource with explicit depends_on ─────────────────────────────
# depends_on is needed here because null_resource has no attribute references
# that would create implicit edges to the file resources.

resource "null_resource" "post_deploy" {
  triggers = {
    config_id   = random_id.project.hex
    environment = var.environment
  }

  provisioner "local-exec" {
    command = <<-SHELL
      echo "[post-deploy] config=${var.project_name} env=${var.environment} id=${random_id.project.hex}"
    SHELL
  }

  # Explicit: run only after all files are written
  depends_on = [
    local_file.dynamic_config,
    local_file.service_manifest,
    local_file.legacy_report,
  ]
}
