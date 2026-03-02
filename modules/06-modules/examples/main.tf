terraform {
  required_version = ">= 1.6"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

variable "environments" {
  type = map(object({
    files = map(string)
    subdir = optional(string, "")
  }))
  default = {
    dev = {
      files = {
        config = "Development configuration — debug mode ON"
        notes  = "Dev environment notes"
      }
    }
    staging = {
      files = {
        config = "Staging configuration — mirrors production"
        notes  = "Staging environment notes"
      }
    }
    prod = {
      files = {
        config = "Production configuration — hardened"
        notes  = "Production environment notes"
      }
    }
  }
}

# Instantiate the file-generator module once per environment
module "env_files" {
  for_each = var.environments
  source   = "./file-generator"

  output_dir  = "output/${each.key}"
  files       = each.value.files
  environment = each.key
  file_prefix = each.key
}

# Combined index of all generated files
resource "local_file" "master_index" {
  filename = "output/master-index.txt"
  content  = join("\n", flatten([
    "Master File Index",
    "=================",
    "",
    [for env, mod in module.env_files : [
      "[${env}]",
      join("\n", [for k, p in mod.file_paths : "  ${k} => ${p}"]),
      ""
    ]]
  ]))
}

output "all_paths" {
  description = "All generated file paths grouped by environment"
  value       = { for env, mod in module.env_files : env => mod.file_paths }
}

output "total_files" {
  description = "Total number of files created across all environments"
  value       = sum([for mod in module.env_files : mod.file_count])
}
