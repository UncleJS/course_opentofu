variable "output_dir" {
  type        = string
  description = "Directory to write files into"

  validation {
    condition     = length(var.output_dir) > 0
    error_message = "output_dir must not be empty."
  }
}

variable "files" {
  type        = map(string)
  description = "Map of filename (without extension) to file content"

  validation {
    condition     = length(var.files) > 0
    error_message = "At least one file must be specified."
  }
}

variable "file_prefix" {
  type        = string
  description = "Optional prefix prepended to each filename"
  default     = ""
}

variable "file_permission" {
  type        = string
  description = "Unix file permissions (e.g. 0644)"
  default     = "0644"

  validation {
    condition     = can(regex("^0[0-7]{3}$", var.file_permission))
    error_message = "file_permission must be a valid 4-digit octal string (e.g. 0644)."
  }
}

variable "environment" {
  type        = string
  description = "Environment label added to each file's metadata footer"
  default     = "default"
}
