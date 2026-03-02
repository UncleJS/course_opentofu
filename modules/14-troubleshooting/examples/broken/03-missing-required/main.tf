# ── BUG: required variable has no default and is not supplied ─────────────
# Error: No value for required variable
#
# FIX option A: add a default to the variable in variables.tf
# FIX option B: pass it at plan time: tofu plan -var="owner_team=platform"

variable "project_name" {
  description = "Project name."
  type        = string
  default     = "broken-03"
}

# BUG: this variable is required (no default) but never passed
variable "owner_team" {
  description = "Team responsible for this project."
  type        = string
  # no default → required
}

resource "local_file" "config" {
  filename        = "/tmp/tofu-broken-03/config.json"
  file_permission = "0644"

  content = jsonencode({
    project = var.project_name
    owner   = var.owner_team  # references the required variable
  })
}
