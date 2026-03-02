output "config_path" {
  description = "Path to the generated app configuration file"
  value       = local_file.app_config.filename
}

output "summary_path" {
  description = "Path to the human-readable deployment summary"
  value       = local_file.deployment_summary.filename
}

output "app_summary" {
  description = "Human-readable deployment summary string"
  value = "App '${var.app.name}' deployed to '${var.app.environment}' with ${local.effective_replicas} replica(s)"
}

output "effective_replicas" {
  description = "Actual replica count after production minimum enforcement"
  value       = local.effective_replicas
}

output "is_production" {
  description = "Whether this is a production deployment"
  value       = local.is_production
}
