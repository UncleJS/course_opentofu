variable "project_name" {
  description = "Name of the project — used as a namespace for all generated files."
  type        = string
  default     = "state-demo"
}

variable "environment" {
  description = "Deployment environment (dev / staging / prod)."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "output_dir" {
  description = "Base directory where all generated artefacts will be written."
  type        = string
  default     = "/tmp/tofu-state-demo"
}

variable "resource_count" {
  description = "How many numbered config files to create (1–10)."
  type        = number
  default     = 3

  validation {
    condition     = var.resource_count >= 1 && var.resource_count <= 10
    error_message = "resource_count must be between 1 and 10."
  }
}

variable "drift_simulation" {
  description = <<-EOT
    When true, a 'drifted' null_resource is included whose triggers will
    differ from the recorded state on the second apply — demonstrating how
    OpenTofu detects and handles configuration drift.
  EOT
  type        = bool
  default     = false
}
