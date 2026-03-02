output "project_id" {
  description = "Stable hex project ID."
  value       = random_id.project.hex
}

output "active_services" {
  description = "Map of enabled services with their configuration."
  value       = local.active_services
}

output "disabled_services" {
  description = "List of service names that are disabled."
  value = [
    for name, svc in var.services :
    name if !svc.enabled
  ]
}

output "section_count" {
  description = "Number of dynamic sections generated."
  value       = length(local.sections)
}

output "dynamic_config_path" {
  description = "Path to the generated dynamic config file."
  value       = local_file.dynamic_config.filename
}

output "service_manifest_path" {
  description = "Path to the generated service manifest file."
  value       = local_file.service_manifest.filename
}
