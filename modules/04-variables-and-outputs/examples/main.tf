locals {
  # Derived values computed from inputs
  is_production = var.app.environment == "prod"
  effective_replicas = local.is_production ? max(var.app.replicas, 2) : var.app.replicas

  # Common labels applied to generated files
  metadata = {
    app         = var.app.name
    environment = var.app.environment
    managed_by  = "opentofu"
  }

  # Feature flag summary string
  feature_summary = length(var.app.feature_flags) == 0 ? "none" : join(", ", [
    for flag, enabled in var.app.feature_flags : "${flag}=${enabled}"
  ])
}

# Ensure output directory exists
resource "local_file" "gitkeep" {
  filename = "${var.output_dir}/.gitkeep"
  content  = ""
}

# Generate the app configuration file
resource "local_file" "app_config" {
  depends_on = [local_file.gitkeep]
  filename   = "${var.output_dir}/${var.app.name}-${var.app.environment}.json"

  content = jsonencode({
    name          = var.app.name
    environment   = var.app.environment
    replicas      = local.effective_replicas
    log_level     = var.app.log_level
    feature_flags = var.app.feature_flags
    metadata      = local.metadata
  })

  file_permission = "0644"
}

# Generate a human-readable deployment summary
resource "local_file" "deployment_summary" {
  depends_on = [local_file.app_config]
  filename   = "${var.output_dir}/${var.app.name}-summary.txt"

  content = <<-EOT
    ====================================
    Deployment Summary
    ====================================
    App Name    : ${var.app.name}
    Environment : ${var.app.environment}
    Replicas    : ${local.effective_replicas}${local.is_production ? " (production minimum enforced)" : ""}
    Log Level   : ${var.app.log_level}
    Features    : ${local.feature_summary}
    Config File : ${local_file.app_config.filename}
    ====================================
  EOT
}
