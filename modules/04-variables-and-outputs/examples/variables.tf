variable "app" {
  type = object({
    name        = string
    environment = string
    replicas    = optional(number, 1)
    feature_flags = optional(map(bool), {})
    log_level   = optional(string, "info")
  })

  default = {
    name        = "my-app"
    environment = "dev"
  }

  description = "Application deployment configuration"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,61}[a-z0-9]$", var.app.name))
    error_message = "App name must be 3-63 chars, lowercase alphanumeric and hyphens, start with letter."
  }

  validation {
    condition     = contains(["dev", "staging", "prod"], var.app.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }

  validation {
    condition     = var.app.replicas >= 1 && var.app.replicas <= 20
    error_message = "Replicas must be between 1 and 20."
  }

  validation {
    condition     = contains(["trace", "debug", "info", "warn", "error"], var.app.log_level)
    error_message = "Log level must be one of: trace, debug, info, warn, error."
  }
}

variable "output_dir" {
  type        = string
  default     = "output"
  description = "Directory to write output files into"
}
