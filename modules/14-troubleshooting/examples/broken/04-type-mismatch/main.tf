# ── BUG: variable type is number but default is a string ──────────────────
# Error: Invalid value for input variable
#
# FIX: change default = "three" to default = 3

variable "replica_count" {
  description = "Number of replicas to create."
  type        = number
  # BUG IS HERE ↓ — string value for a number type
  default     = "three"
}

resource "local_file" "config" {
  filename        = "/tmp/tofu-broken-04/config.json"
  file_permission = "0644"

  content = jsonencode({
    replicas = var.replica_count
  })
}
