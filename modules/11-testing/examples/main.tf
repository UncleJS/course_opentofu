# ============================================================
# Module 11 — Testing: worked example
#
# A deliberately simple configuration with:
#  - Multiple input variables (each with validation blocks)
#  - A for_each resource (tests the count assertions)
#  - Outputs that the .tftest.hcl files assert against
# ============================================================

resource "random_id" "project" {
  byte_length = 8
  keepers = {
    project     = var.project_name
    environment = var.environment
  }
}

locals {
  services = {
    for i in range(var.file_count) :
    format("svc-%02d", i + 1) => {
      index = i + 1
      path  = "${var.output_dir}/${var.environment}/svc-${format("%02d", i + 1)}.json"
    }
  }
}

resource "local_file" "env_marker" {
  filename        = "${var.output_dir}/${var.environment}/.keep"
  content         = "# managed by OpenTofu\n"
  file_permission = "0644"
}

resource "local_file" "service_config" {
  for_each = local.services

  filename        = each.value.path
  file_permission = "0644"

  content = jsonencode(merge(var.tags, {
    service     = each.key
    index       = each.value.index
    project_id  = random_id.project.hex
    environment = var.environment
    project     = var.project_name
  }))

  depends_on = [local_file.env_marker]
}
