variable "project_name" {
  description = "Project namespace."
  type        = string
  default     = "cicd-demo"
}

variable "environment" {
  description = "Target environment (dev / staging / prod)."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "output_dir" {
  description = "Base directory for generated artefacts."
  type        = string
  default     = "/tmp/tofu-cicd-demo"
}

variable "resource_count" {
  description = "Number of config files to create (used in the plan-gate exercise)."
  type        = number
  default     = 3
}

variable "app_version" {
  description = "Simulated application version — change this to trigger a plan diff."
  type        = string
  default     = "1.0.0"
}
