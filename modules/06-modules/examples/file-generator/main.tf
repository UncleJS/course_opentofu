locals {
  prefix = var.file_prefix != "" ? "${var.file_prefix}-" : ""
}

resource "local_file" "files" {
  for_each = var.files

  filename        = "${var.output_dir}/${local.prefix}${each.key}.txt"
  file_permission = var.file_permission

  content = <<-EOT
    ${each.value}

    ---
    environment : ${var.environment}
    managed_by  : opentofu (file-generator module)
  EOT
}
