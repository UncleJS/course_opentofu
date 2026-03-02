# ============================================================
# Module 09 — Backends & Remote State: worked example
#
# What this configuration demonstrates
# ─────────────────────────────────────
#  1. Explicit local backend declaration in versions.tf
#  2. State locking (the local backend uses a .tflock file)
#  3. terraform_remote_state data source (reading outputs from
#     a *separate* configuration stored in remote_state_dir)
#  4. State encryption snippet generation (OpenTofu ≥ 1.7)
#  5. Workspace-aware state paths
#  6. Backend migration workflow (documented in comments)
#
# Because the `terraform_remote_state` data source requires a
# real state file to exist, this config first creates a "producer"
# state file, then reads it back — all using the local backend.
# ============================================================

locals {
  state_key = "${var.project_name}/${var.environment}/terraform.tfstate"

  # Encryption snippet — written to a file so learners can inspect it.
  encryption_snippet = <<-HCL
    # ── OpenTofu Native State Encryption (≥ 1.7) ──────────────────────────
    # Add inside your terraform {} block in versions.tf:
    #
    # encryption {
    #   key_provider "pbkdf2" "local" {
    #     passphrase = var.state_encryption_passphrase   # from env or vault
    #   }
    #
    #   method "aes_gcm" "default" {
    #     keys = key_provider.pbkdf2.local
    #   }
    #
    #   state {
    #     method = method.aes_gcm.default
    #     enforced = true   # reject unencrypted state reads
    #   }
    #
    #   plan {
    #     method = method.aes_gcm.default
    #   }
    # }
    #
    # Rotate keys with:
    #   tofu apply   (OpenTofu re-encrypts state with the new key on next write)
    # ──────────────────────────────────────────────────────────────────────
  HCL
}

# ── 1. Output directory ───────────────────────────────────────────────────────
resource "local_file" "output_dir_marker" {
  filename        = "${var.output_dir}/${var.environment}/.keep"
  content         = "# managed by OpenTofu\n"
  file_permission = "0644"
}

# ── 2. Stable project ID ──────────────────────────────────────────────────────
resource "random_id" "project" {
  byte_length = 6
  keepers = {
    project     = var.project_name
    environment = var.environment
  }
}

# ── 3. "Producer" state — write outputs that a consumer will read back ────────
# In a real multi-team setup this would be a separate Terraform root module
# managed by another team (e.g. the networking team's VPC config).
# Here we simulate it by writing a JSON file that looks like a minimal state.

resource "local_file" "producer_state" {
  filename        = "${var.remote_state_dir}/producer/terraform.tfstate"
  file_permission = "0600"

  content = jsonencode({
    version           = 4
    terraform_version = "1.6.0"
    serial            = 1
    lineage           = random_id.project.hex
    outputs = {
      shared_project_id = {
        value = random_id.project.hex
        type  = "string"
      }
      shared_environment = {
        value = var.environment
        type  = "string"
      }
    }
    resources = []
  })
}

# ── 4. Read back the producer state ──────────────────────────────────────────
# `terraform_remote_state` is the standard cross-stack output-sharing pattern.
# It reads the *outputs* block of another configuration's state file.
#
# Under the hood OpenTofu fetches the state through the backend's GetState RPC,
# decodes it with the same encryption config if present, and exposes `.outputs`.

data "terraform_remote_state" "producer" {
  backend = "local"

  config = {
    path = "${var.remote_state_dir}/producer/terraform.tfstate"
  }

  # Wait until the producer state file actually exists
  depends_on = [local_file.producer_state]
}

# ── 5. Consumer resource: uses a value from the remote state ─────────────────
resource "local_file" "consumer_config" {
  filename        = "${var.output_dir}/${var.environment}/consumer.json"
  file_permission = "0644"

  content = jsonencode({
    # Values sourced from the *other* configuration's outputs via remote state
    upstream_project_id  = data.terraform_remote_state.producer.outputs.shared_project_id
    upstream_environment = data.terraform_remote_state.producer.outputs.shared_environment
    # Values from *this* configuration
    local_project_name = var.project_name
    state_key          = local.state_key
  })

  depends_on = [local_file.output_dir_marker]
}

# ── 6. Encryption snippet file (informational) ───────────────────────────────
resource "local_file" "encryption_snippet" {
  count = var.enable_encryption_example ? 1 : 0

  filename        = "${var.output_dir}/${var.environment}/encryption-example.hcl"
  file_permission = "0644"
  content         = local.encryption_snippet
}

# ── 7. Backend migration guide ────────────────────────────────────────────────
# Written as a plain-text file so learners have a reference they can open.

resource "local_file" "migration_guide" {
  filename        = "${var.output_dir}/${var.environment}/backend-migration.md"
  file_permission = "0644"

  content = <<-GUIDE
    # Backend Migration Cheatsheet

    ## local → HTTP (e.g. GitLab)
    1. Update the `backend "http" {}` block in versions.tf
    2. Run: tofu init -migrate-state
       OpenTofu will prompt: "Do you want to copy the existing state?"  → yes
    3. Verify: tofu state list  (should show the same resources)
    4. Delete the old terraform.tfstate file

    ## HTTP → local (rollback)
    1. Restore the `backend "local" {}` block
    2. Run: tofu init -migrate-state
    3. Verify: tofu state list

    ## State locking
    The local backend creates a `.terraform.tfstate.lock.info` file during
    apply/plan.  If a run is interrupted, remove the lock with:
      tofu force-unlock <lock-id>

    ## Partial backend configuration
    Sensitive values (tokens, passwords) should be passed at init time,
    not stored in .tf files:
      tofu init -backend-config="token=\$TF_HTTP_TOKEN"

    ## State inspection
      tofu state list
      tofu state show local_file.consumer_config
      tofu state pull | jq '.outputs'
  GUIDE
}
