output "build_id" {
  description = "Unique build identifier — changes when app_version or environment changes."
  value       = random_id.build.hex
}

output "deployed_services" {
  description = "Map of service name → deployed file path."
  value       = { for k, v in local_file.deployment : k => v.filename }
}

output "environment" {
  description = "Active environment for this deployment."
  value       = var.environment
}

output "app_version" {
  description = "Application version that was deployed."
  value       = var.app_version
}
