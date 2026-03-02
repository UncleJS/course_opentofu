# ============================================================
# Module 10 — CI/CD Integration: worked example
#
# This configuration is deliberately simple so the CI/CD
# pipeline mechanics (plan/apply gate, drift detection,
# -detailed-exitcode) are clearly observable without noise.
# ============================================================

resource "random_id" "build" {
  byte_length = 6
  keepers = {
    project     = var.project_name
    environment = var.environment
    app_version = var.app_version
  }
}

resource "local_file" "env_marker" {
  filename        = "${var.output_dir}/${var.environment}/.keep"
  content         = "# managed by OpenTofu\n"
  file_permission = "0644"
}

resource "local_file" "deployment" {
  for_each = { for i in range(var.resource_count) : format("svc-%02d", i + 1) => i + 1 }

  filename        = "${var.output_dir}/${var.environment}/${each.key}.json"
  file_permission = "0644"

  content = jsonencode({
    service     = each.key
    version     = var.app_version
    build_id    = random_id.build.hex
    environment = var.environment
  })

  depends_on = [local_file.env_marker]
}

resource "null_resource" "pipeline_checkpoint" {
  triggers = {
    build_id    = random_id.build.hex
    app_version = var.app_version
  }

  provisioner "local-exec" {
    command = "echo '[pipeline] deployed ${var.app_version} (${random_id.build.hex}) to ${var.environment}'"
  }
}
