variable "project_name" {
  description = "Project namespace used for file naming and state key labelling."
  type        = string
  default     = "backend-demo"
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
  description = "Base directory for all generated artefacts."
  type        = string
  default     = "/tmp/tofu-backend-demo"
}

variable "enable_encryption_example" {
  description = <<-EOT
    When true, writes a companion HCL snippet showing how to configure
    OpenTofu's native state encryption (introduced in OpenTofu 1.7).
    The snippet is written to a local file — no encryption is actually
    applied to the demo state (which would require a KMS key).
  EOT
  type        = bool
  default     = true
}

variable "remote_state_dir" {
  description = <<-EOT
    Path to a directory that simulates a 'remote' state store.
    In the data-source exercise a second configuration writes state here,
    and this configuration reads it back via `terraform_remote_state`.
  EOT
  type        = string
  default     = "/tmp/tofu-remote-state"
}
