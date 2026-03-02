variable "environments" {
  type = map(string)
  default = {
    dev     = "Development environment — fast iteration, debug enabled"
    staging = "Staging environment — mirrors production"
    prod    = "Production environment — stable, monitored"
  }
  description = "Map of environment name to description"
}

variable "output_dir" {
  type        = string
  default     = "output"
  description = "Directory to write output files into"
}
