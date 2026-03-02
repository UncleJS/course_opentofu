output "project_id" {
  description = "Stable hex project ID for this healthcheck run."
  value       = random_id.project.hex
}

output "report_path" {
  description = "Absolute path of the generated healthcheck report file."
  value       = local_file.report.filename
}
