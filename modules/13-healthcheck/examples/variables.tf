variable "project_name" {
  description = "Project name — used as a namespace in generated file names."
  type        = string
  default     = "healthcheck-demo"
}

variable "output_dir" {
  description = "Base directory for generated artefacts."
  type        = string
  default     = "/tmp/tofu-healthcheck-demo"
}
