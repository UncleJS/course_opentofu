terraform {
  required_version = ">= 1.6.0"

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

  # ── Local backend (default) ─────────────────────────────────────────────────
  # The local backend stores terraform.tfstate in the current directory.
  # This is the default when no `backend` block is specified, but declaring it
  # explicitly makes the intent clear and allows learners to swap to another
  # backend by changing only this block.
  #
  # To switch to an HTTP backend (e.g. GitLab-managed state), replace with:
  #
  #   backend "http" {
  #     address        = "https://gitlab.example.com/api/v4/projects/1/terraform/state/module-09"
  #     lock_address   = "..."
  #     unlock_address = "..."
  #   }
  #
  # Then run: tofu init -reconfigure
  backend "local" {
    path = "terraform.tfstate"
  }
}
