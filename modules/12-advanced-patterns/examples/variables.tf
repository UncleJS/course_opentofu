variable "project_name" {
  description = "Project namespace."
  type        = string
  default     = "advanced-demo"
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

variable "approved_by" {
  description = "Name of the person who approved this deployment. Required for prod."
  type        = string
  default     = ""
}

variable "output_dir" {
  description = "Base directory for generated artefacts."
  type        = string
  default     = "/tmp/tofu-advanced-demo"
}

# ── Dynamic block demo ─────────────────────────────────────────────────────
variable "section_count" {
  description = "Number of dynamic sections to include in the generated config (1–6)."
  type        = number
  default     = 3

  validation {
    condition     = var.section_count >= 1 && var.section_count <= 6
    error_message = "section_count must be between 1 and 6."
  }
}

# ── Complex object type demo ───────────────────────────────────────────────
variable "services" {
  description = "Map of services to deploy. Demonstrates complex object types."
  type = map(object({
    port        = number
    protocol    = optional(string, "tcp")
    enabled     = optional(bool, true)
    replicas    = optional(number, 1)
    tags        = optional(map(string), {})
  }))

  default = {
    "api" = {
      port     = 8080
      protocol = "tcp"
      replicas = 2
      tags     = { tier = "backend" }
    }
    "web" = {
      port     = 3000
      protocol = "tcp"
      tags     = { tier = "frontend" }
    }
    "worker" = {
      port    = 0
      enabled = false
    }
  }

  validation {
    condition = alltrue([
      for name, svc in var.services :
      svc.port >= 0 && svc.port <= 65535
    ])
    error_message = "All service ports must be in the range 0–65535."
  }

  validation {
    condition = alltrue([
      for name, svc in var.services :
      contains(["tcp", "udp"], svc.protocol)
    ])
    error_message = "Service protocol must be 'tcp' or 'udp'."
  }
}
