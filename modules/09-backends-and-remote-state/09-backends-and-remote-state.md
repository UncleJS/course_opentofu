# Module 09 — Backends & Remote State

<!-- SPDX-License-Identifier: CC-BY-NC-SA-4.0 -->

[![Module](https://img.shields.io/badge/Module-09-blue)](.)
[![Difficulty](https://img.shields.io/badge/Difficulty-Advanced-red)](.)
[![Time](https://img.shields.io/badge/Time-90%20min-lightgrey)](.)
[![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)

---

## Table of Contents

- [Overview](#overview)
- [Backend Concepts Deep-Dive](#backend-concepts-deep-dive)
- [Local Backend Internals](#local-backend-internals)
- [HTTP Backend](#http-backend)
- [S3-Compatible Backend](#s3-compatible-backend)
- [Remote State Data Source](#remote-state-data-source)
- [Partial Configuration](#partial-configuration)
- [Backend Migration](#backend-migration)
- [Encryption at Rest (OpenTofu 1.7+)](#encryption-at-rest-opentofu-17)
- [Exercises](#exercises)
- [Further Reading](#further-reading)
- [Summary](#summary)
- [Next Module →](#next-module-)

---

## Overview

As soon as more than one person works on infrastructure, or you need to run OpenTofu in CI/CD, the local backend becomes inadequate. Remote backends provide team collaboration, state locking, and state history.

This module covers every backend concept in depth, including OpenTofu's unique state encryption feature that Terraform does not have.

↑ [Back to Table of Contents](#table-of-contents)

---

## Backend Concepts Deep-Dive

### What a Backend Does

A backend has two jobs:

1. **State storage** — where the state file lives (local file, S3 object, HTTP endpoint, etc.)
2. **State locking** — prevents concurrent modifications (DynamoDB table, database row, etc.)

Some backends also support **remote operations** (running plan/apply remotely) — these are called **enhanced backends**. The Terraform Cloud / HCP Terraform backend is the main example.

### Standard vs Enhanced Backends

| Type | Storage | Locking | Remote Ops |
|---|---|---|---|
| **Standard** | ✅ | ✅ (most) | ❌ |
| **Enhanced** | ✅ | ✅ | ✅ |

Most teams use a standard backend (S3, GCS, Azure Blob) — remote operations are generally better handled by CI/CD pipelines.

### Backend Configuration Block

```hcl
terraform {
  backend "s3" {
    # backend-specific configuration here
  }
}
```

The backend block must be static — no variable references, no `local` values, no interpolation. This is because the backend is initialised before the rest of the configuration is loaded.

↑ [Back to Table of Contents](#table-of-contents)

---

## Local Backend Internals

The local backend stores state as a JSON file on disk. It is the default when no backend is configured.

```hcl
terraform {
  backend "local" {
    path          = "terraform.tfstate"       # state file path
    workspace_dir = "terraform.tfstate.d"     # workspace state dir
  }
}
```

### File Locking

The local backend acquires a lock by creating a `.tfstate.lock.info` file alongside the state:

```json
{
  "ID": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "Operation": "OperationTypeApply",
  "Info": "",
  "Who": "alice@laptop",
  "Version": "1.8.0",
  "Created": "2026-03-02T10:00:00.000000000Z",
  "Path": "terraform.tfstate"
}
```

If the lock file exists when another process tries to apply, the operation fails with a "state lock" error.

### `-state` and `-state-out` Flags

```bash
# Read state from a non-default path
tofu plan -state=other.tfstate

# Write state to a different file (useful for testing)
tofu apply -state=input.tfstate -state-out=output.tfstate
```

↑ [Back to Table of Contents](#table-of-contents)

---

## HTTP Backend

The HTTP backend stores state on any REST API endpoint that implements a specific protocol.

```hcl
terraform {
  backend "http" {
    address        = "https://my-state-server.example.com/state/my-project"
    lock_address   = "https://my-state-server.example.com/lock/my-project"
    unlock_address = "https://my-state-server.example.com/lock/my-project"
    username       = "tofu-user"
    password       = "secret"   # use partial config for this

    # Optional
    lock_method   = "PUT"     # default
    unlock_method = "DELETE"  # default
    update_method = "POST"    # default
  }
}
```

### HTTP Backend Protocol

| Operation | HTTP Method | Endpoint |
|---|---|---|
| Get state | GET | `address` |
| Update state | POST (or PUT) | `address` |
| Lock state | PUT | `lock_address` |
| Unlock state | DELETE | `unlock_address` |

The HTTP backend is useful for building custom state servers or integrating with existing API infrastructure.

↑ [Back to Table of Contents](#table-of-contents)

---

## S3-Compatible Backend

The S3 backend is the most widely-used remote backend. It works with AWS S3 and any S3-compatible storage (MinIO, Cloudflare R2, DigitalOcean Spaces, etc.).

### Full Configuration

```hcl
terraform {
  backend "s3" {
    # Required
    bucket = "my-tofu-state-bucket"
    key    = "projects/my-app/terraform.tfstate"
    region = "us-east-1"

    # State locking (DynamoDB)
    dynamodb_table = "tofu-state-locks"

    # Encryption
    encrypt        = true
    kms_key_id     = "arn:aws:kms:us-east-1:123456789:key/abc123"

    # Versioning (for state history)
    # Enable versioning on the S3 bucket itself (not configured here)

    # Access (typically from environment variables or IAM role)
    # access_key = "..."   — use env vars instead
    # secret_key = "..."   — use env vars instead
  }
}
```

### S3 Bucket Requirements

```
Bucket settings:
  ✅ Versioning enabled (for state history and recovery)
  ✅ Server-side encryption (AES-256 or KMS)
  ✅ Block all public access
  ✅ Access logging enabled (for audit)

DynamoDB table requirements:
  ✅ Partition key: "LockID" (string)
  ✅ Billing mode: PAY_PER_REQUEST (or provisioned with low capacity)
```

### Minimum IAM Permissions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketVersioning"
      ],
      "Resource": [
        "arn:aws:s3:::my-tofu-state-bucket",
        "arn:aws:s3:::my-tofu-state-bucket/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:us-east-1:123456789:table/tofu-state-locks"
    }
  ]
}
```

### Using with MinIO (Provider-Agnostic Demo)

MinIO is an S3-compatible object store you can run locally:

```bash
# Run MinIO with Podman
podman run -p 9000:9000 -p 9001:9001 \
  -e MINIO_ROOT_USER=minioadmin \
  -e MINIO_ROOT_PASSWORD=minioadmin \
  quay.io/minio/minio server /data --console-address ":9001"
```

```hcl
terraform {
  backend "s3" {
    bucket                      = "tofu-state"
    key                         = "dev/terraform.tfstate"
    region                      = "us-east-1"   # required but ignored by MinIO
    endpoint                    = "http://localhost:9000"
    access_key                  = "minioadmin"
    secret_key                  = "minioadmin"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }
}
```

↑ [Back to Table of Contents](#table-of-contents)

---

## Remote State Data Source

The `terraform_remote_state` data source reads outputs from another configuration's state.

```hcl
# Read outputs from a "network" configuration
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "my-tofu-state-bucket"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

# Use the network's outputs
resource "local_file" "app_config" {
  filename = "output/app.conf"
  content  = "vpc_id = ${data.terraform_remote_state.network.outputs.vpc_id}"
}
```

### Cross-Stack Output Sharing

```
┌─────────────────────────┐     remote_state     ┌─────────────────────────┐
│   network config        │ ──────────────────► │   app config            │
│   outputs:              │                      │   uses:                 │
│     vpc_id              │                      │     data.network.vpc_id │
│     subnet_ids          │                      │     data.network.subnets│
└─────────────────────────┘                      └─────────────────────────┘
```

### Coupling Risk and Alternatives

`terraform_remote_state` creates a **tight coupling** between configurations — the app config depends on the exact output names from the network config. If the network team renames an output, the app config breaks.

**Alternatives with looser coupling:**

| Alternative | Coupling | Notes |
|---|---|---|
| `terraform_remote_state` | High | Direct state access |
| SSM Parameter Store | Low | Network writes to SSM; app reads from SSM |
| Consul | Low | Network writes to Consul KV; app reads from it |
| Hardcoded values | None | Simplest; not maintainable at scale |

↑ [Back to Table of Contents](#table-of-contents)

---

## Partial Configuration

Sensitive backend configuration (credentials, bucket names) should not be committed to source control. **Partial configuration** separates secrets from the `backend` block.

### In the `backend` Block (non-sensitive only)

```hcl
# versions.tf — committed to git
terraform {
  backend "s3" {
    key    = "projects/my-app/terraform.tfstate"
    region = "us-east-1"
    # bucket, access_key, secret_key are NOT here
  }
}
```

### Supplying the Rest at `init` Time

```bash
# Via command-line flags
tofu init \
  -backend-config="bucket=my-tofu-state-bucket" \
  -backend-config="dynamodb_table=tofu-state-locks"

# Via a backend config file (not committed to git, in .gitignore)
tofu init -backend-config=backend.hcl
```

```hcl
# backend.hcl — in .gitignore
bucket         = "my-tofu-state-bucket"
dynamodb_table = "tofu-state-locks"
```

### CI/CD Injection Pattern

```bash
# In CI/CD pipeline: inject backend config from secrets manager
export TF_CLI_ARGS_init="-backend-config=bucket=${STATE_BUCKET} -backend-config=dynamodb_table=${LOCK_TABLE}"
tofu init
```

↑ [Back to Table of Contents](#table-of-contents)

---

## Backend Migration

### Local to Remote

```bash
# 1. Add backend configuration to versions.tf
# 2. Run init — OpenTofu detects the backend change
tofu init

# Output:
# Initializing the backend...
# Do you want to copy existing state to the new backend?
#   > yes

# 3. Verify migration
tofu state list   # should show same resources from new backend
```

### Remote to Remote

```bash
# 1. Update backend configuration in versions.tf
# 2. Run init -migrate-state
tofu init -migrate-state

# 3. Verify
tofu state list
tofu plan   # should show no changes
```

### Migration Safety Checklist

- [ ] Back up current state: `tofu state pull > backup.tfstate`
- [ ] Ensure no one is running `tofu apply` during migration
- [ ] Verify new backend credentials are working before init
- [ ] After migration: verify `tofu state list` matches backup
- [ ] After migration: run `tofu plan` — should show zero changes
- [ ] Keep backup for at least 30 days

↑ [Back to Table of Contents](#table-of-contents)

---

## Encryption at Rest (OpenTofu 1.7+)

OpenTofu 1.7 introduced native state and plan file encryption — a feature not available in Terraform.

### Basic Encryption Configuration

```hcl
terraform {
  encryption {
    key_provider "pbkdf2" "my_passphrase" {
      passphrase = var.state_encryption_passphrase  # sensitive variable
    }

    method "aes_gcm" "default_method" {
      keys = key_provider.pbkdf2.my_passphrase
    }

    state {
      method = method.aes_gcm.default_method
    }

    plan {
      method = method.aes_gcm.default_method
    }
  }
}
```

### Key Providers

| Provider | Use Case | Notes |
|---|---|---|
| `pbkdf2` | Simple passphrase-based | Good for learning; not for production |
| `aws_kms` | AWS KMS managed keys | Production AWS deployments |
| `gcp_kms` | GCP Cloud KMS | Production GCP deployments |
| `openbao` | HashiCorp Vault / OpenBao | Self-hosted key management |

### AWS KMS Key Provider

```hcl
terraform {
  encryption {
    key_provider "aws_kms" "prod_key" {
      kms_key_id = "arn:aws:kms:us-east-1:123456789:key/abc123"
      region     = "us-east-1"
      key_spec   = "AES_256"
    }

    method "aes_gcm" "kms_method" {
      keys = key_provider.aws_kms.prod_key
    }

    state {
      method = method.aes_gcm.kms_method
    }
  }
}
```

### Enabling Encryption on Existing State

```hcl
terraform {
  encryption {
    key_provider "pbkdf2" "my_key" {
      passphrase = var.passphrase
    }
    method "aes_gcm" "main" {
      keys = key_provider.pbkdf2.my_key
    }
    state {
      method  = method.aes_gcm.main
      # Allow reading unencrypted state (for migration from unencrypted)
      fallback {
        method = method.unencrypted.migrate
      }
    }
  }
}
```

↑ [Back to Table of Contents](#table-of-contents)

---

## Exercises

### Exercise 1 — Easy: Backend Config Migration

1. Take the Module 03 example (local backend)
2. Create a `backend.hcl` file and add it to `.gitignore`
3. Reconfigure to use a local backend at a different path using `-backend-config`
4. Run `tofu init -backend-config=backend.hcl` and migrate state
5. Verify with `tofu state list` and `tofu plan` (should show no changes)
6. Inspect the new state file location — confirm state was migrated

---

### Exercise 2 — Medium: HTTP Backend Mock

1. Install `json-server` or write a minimal HTTP backend mock (shell script using `nc` or Python's `http.server`)
2. Configure the HTTP backend to point to your mock
3. Apply a simple config and observe the HTTP requests (GET, POST, PUT for lock/unlock)
4. Simulate a lock by making the lock endpoint return a 423 status
5. Observe the error message and identify the lock ID
6. Document the full HTTP backend protocol with request/response examples

---

### Exercise 3 — Hard: State Encryption with PBKDF2

1. Create a config using the `pbkdf2` key provider to encrypt state
2. Apply the config and inspect the state file — confirm it is encrypted (binary, not JSON)
3. Rotate the passphrase: add a `fallback` block for the old key while introducing the new key
4. Apply again — confirm the re-encryption works (state uses new key, old key in fallback)
5. Remove the fallback block and apply — confirm the old key is no longer needed
6. Write a runbook for the passphrase rotation procedure with rollback steps

↑ [Back to Table of Contents](#table-of-contents)

---

## Further Reading

- [OpenTofu Backend Configuration](https://opentofu.org/docs/language/settings/backends/) — All backend types
- [S3 Backend Docs](https://opentofu.org/docs/language/settings/backends/s3/) — Full S3 backend reference
- [State Encryption (OpenTofu)](https://opentofu.org/docs/language/state/encryption/) — Encryption feature documentation
- [Remote State Data Source](https://opentofu.org/docs/language/state/remote-state-data/) — Cross-stack state sharing
- [MinIO Documentation](https://min.io/docs/minio/linux/index.html) — S3-compatible local storage
- [Backend Migration Guide](https://opentofu.org/docs/cli/commands/init/#backend-initialization) — Official migration docs

↑ [Back to Table of Contents](#table-of-contents)

---

## Summary

| Concept | Key Takeaway |
|---|---|
| Backend | Provides state storage + locking; some provide remote ops |
| Local backend | Default; file-based locking; not suitable for teams |
| S3 backend | Most common remote; requires S3 bucket + DynamoDB lock table |
| Partial config | Separate secrets from backend block; inject via `-backend-config` |
| `terraform_remote_state` | Share outputs between configs; creates tight coupling |
| Backend migration | `tofu init -migrate-state`; always back up first |
| State encryption | OpenTofu 1.7+; PBKDF2/KMS key providers; not available in Terraform |

↑ [Back to Table of Contents](#table-of-contents)

---

## Next Module →

**[Module 10 — CI/CD Integration](../10-cicd-integration/10-cicd-integration.md)**

Build production-grade pipelines: plan on PR, apply on merge, drift detection, OIDC auth, and policy as code.


---

<sub>© 2026 UncleJS & Course OpenTofu contributors — licensed under [CC BY-NC-SA 4.0](../../LICENSE).<br>
You may share and adapt this material for non-commercial purposes with attribution.<br>
SPDX-License-Identifier: CC-BY-NC-SA-4.0</sub>