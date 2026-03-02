# ── BUG: backend "local" path points to an existing regular file ──────────
# The local backend expects `path` to be a writable FILE path (not a dir),
# but this config sets it to a path that would collide with a directory.
#
# Error: Failed to get existing workspaces: ... (or init fails)
#
# FIX: change `path` to a proper .tfstate file path, e.g.:
#   path = "/tmp/tofu-broken-06/terraform.tfstate"

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  backend "local" {
    # BUG IS HERE ↓ — /tmp is a directory, not a valid state file path
    path = "/tmp"
  }
}
