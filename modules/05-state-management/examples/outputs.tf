output "project_id" {
  description = "Stable hex ID derived from project name + environment. Persists in state across applies."
  value       = random_id.project.hex
}

output "output_directory" {
  description = "Absolute path of the environment-specific output directory."
  value       = "${var.output_dir}/${var.environment}"
}

output "config_file_paths" {
  description = "Map of config-name → absolute file path for every generated config file."
  value       = { for k, v in local_file.config : k => v.filename }
}

output "manifest_path" {
  description = "Absolute path of the generated manifest.json file."
  value       = local_file.manifest.filename
}

output "drift_simulation_enabled" {
  description = "Whether the drift-simulation null_resource is active in this apply."
  value       = var.drift_simulation
}

# ── State-exploration hints ───────────────────────────────────────────────────
output "state_commands" {
  description = <<-EOT
    Useful commands to explore and manipulate state for this configuration:

      tofu state list
      tofu state show random_id.project
      tofu state show 'local_file.config["config-01"]'
      tofu state pull | jq '.resources[].type'
      tofu state rm local_file.manifest
      tofu state mv null_resource.checkpoint null_resource.renamed
      tofu apply -target=local_file.manifest
      tofu apply -replace=null_resource.checkpoint
  EOT
  value       = "See description above — run these in the examples/ directory."
}
