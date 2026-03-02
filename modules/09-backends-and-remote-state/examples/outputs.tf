output "project_id" {
  description = "Stable hex ID for this project+environment combination."
  value       = random_id.project.hex
}

output "state_key" {
  description = "Logical state key path (project/environment/terraform.tfstate)."
  value       = local.state_key
}

output "consumer_config_path" {
  description = "Path of the consumer config file that reads from remote state."
  value       = local_file.consumer_config.filename
}

output "upstream_project_id" {
  description = "Project ID read back from the simulated remote (producer) state — demonstrates terraform_remote_state."
  value       = data.terraform_remote_state.producer.outputs.shared_project_id
}

output "encryption_snippet_path" {
  description = "Path of the generated encryption-example.hcl file (null when disabled)."
  value       = var.enable_encryption_example ? local_file.encryption_snippet[0].filename : null
}

output "migration_guide_path" {
  description = "Path of the backend migration guide written by this configuration."
  value       = local_file.migration_guide.filename
}
