resource "random_id" "project" {
  byte_length = 6
  keepers     = { project = var.project_name }
}

resource "local_file" "report" {
  filename        = "${var.output_dir}/healthcheck-report.json"
  file_permission = "0644"

  content = jsonencode({
    project    = var.project_name
    project_id = random_id.project.hex
    checked_at = "run-time"
  })
}
