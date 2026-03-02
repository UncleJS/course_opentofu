variable "project_name" {
  description = "Project namespace."
  type        = string
  default     = "test-demo"

  validation {
    condition     = length(var.project_name) >= 3
    error_message = "project_name must be at least 3 characters."
  }
}

variable "environment" {
  description = "Target environment."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "output_dir" {
  description = "Base directory for generated files."
  type        = string
  default     = "/tmp/tofu-test-demo"
}

variable "file_count" {
  description = "Number of service config files to create (1–5)."
  type        = number
  default     = 2

  validation {
    condition     = var.file_count >= 1 && var.file_count <= 5
    error_message = "file_count must be between 1 and 5."
  }
}

variable "tags" {
  description = "Metadata tags written into every generated file."
  type        = map(string)
  default = {
    owner = "platform-team"
    tier  = "test"
  }
}
