output "project_id" {
  description = "Stable hex project ID."
  value       = random_id.project.hex
}

output "environment" {
  description = "Active environment."
  value       = var.environment
}

output "project_name" {
  description = "Active project name."
  value       = var.project_name
}

output "service_paths" {
  description = "Map of service name → file path for every generated config."
  value       = { for k, v in local_file.service_config : k => v.filename }
}

output "service_count" {
  description = "Number of service config files created."
  value       = length(local_file.service_config)
}
