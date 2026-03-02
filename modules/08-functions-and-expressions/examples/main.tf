terraform {
  required_version = ">= 1.6"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "services" {
  type = map(object({
    name        = string
    port        = number
    protocol    = optional(string, "http")
    environment = optional(string, "dev")
    tags        = optional(map(string), {})
  }))
  default = {
    web = {
      name        = "web-server"
      port        = 8080
      protocol    = "http"
      environment = "dev"
      tags        = { team = "frontend" }
    }
    api = {
      name        = "api-server"
      port        = 3000
      protocol    = "https"
      environment = "dev"
      tags        = { team = "backend" }
    }
    cache = {
      name        = "cache"
      port        = 6379
      protocol    = "tcp"
      environment = "dev"
      tags        = { team = "platform" }
    }
  }
}

locals {
  # Extract all ports as a simple list
  all_ports = [for k, svc in var.services : svc.port]

  # Map of service key → formatted address
  service_addresses = {
    for k, svc in var.services :
    k => "${svc.protocol}://localhost:${svc.port}"
  }

  # Sorted list of service names
  service_names = sort([for k, svc in var.services : svc.name])
}

# Generate Ansible-style inventory
resource "local_file" "inventory" {
  filename = "output/inventory.ini"
  content  = templatefile("${path.module}/templates/inventory.tpl", {
    services = var.services
  })
}

# Generate docker-compose YAML
resource "local_file" "docker_compose" {
  filename = "output/docker-compose.yml"
  content = yamlencode({
    version  = "3.8"
    services = {
      for k, svc in var.services : k => {
        image       = "${svc.name}:latest"
        ports       = ["${svc.port}:${svc.port}"]
        environment = [for envk, envv in svc.tags : "${envk}=${envv}"]
        labels      = svc.tags
      }
    }
  })
}

# Summary report
resource "local_file" "summary" {
  filename = "output/summary.txt"
  content  = templatefile("${path.module}/templates/summary.tpl", {
    services          = var.services
    service_addresses = local.service_addresses
    all_ports         = local.all_ports
    service_names     = local.service_names
  })
}

output "service_addresses" {
  value = local.service_addresses
}

output "generated_files" {
  value = [
    local_file.inventory.filename,
    local_file.docker_compose.filename,
    local_file.summary.filename,
  ]
}
