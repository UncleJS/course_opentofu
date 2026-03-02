terraform {
  required_version = ">= 1.6"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

locals {
  env_config = {
    dev = {
      replicas  = 1
      log_level = "debug"
      files = {
        config = "dev config — debug mode ON"
        notes  = "dev notes"
      }
    }
    staging = {
      replicas  = 2
      log_level = "info"
      files = {
        config = "staging config — mirrors production"
        notes  = "staging notes"
      }
    }
    prod = {
      replicas  = 5
      log_level = "warn"
      files = {
        config = "prod config — hardened"
        notes  = "prod notes"
      }
    }
  }

  # Fall back to "dev" config for the default workspace
  config = lookup(local.env_config, terraform.workspace, local.env_config["dev"])
}

resource "local_file" "workspace_files" {
  for_each = local.config.files

  filename = "output/${terraform.workspace}/${each.key}.txt"
  content  = <<-EOT
    ${each.value}

    workspace : ${terraform.workspace}
    replicas  : ${local.config.replicas}
    log_level : ${local.config.log_level}
  EOT

  file_permission = "0644"
}

output "workspace" {
  value = terraform.workspace
}

output "replica_count" {
  value = local.config.replicas
}

output "file_paths" {
  value = { for k, v in local_file.workspace_files : k => v.filename }
}
