# Module 02 — Installation & Setup

<!-- SPDX-License-Identifier: CC-BY-NC-SA-4.0 -->

[![Module](https://img.shields.io/badge/Module-02-blue)](.)
[![Difficulty](https://img.shields.io/badge/Difficulty-Beginner-green)](.)
[![Time](https://img.shields.io/badge/Time-30%20min-lightgrey)](.)
[![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)

---

## Table of Contents

- [Overview](#overview)
- [Binary Installation Methods](#binary-installation-methods)
- [Version Pinning and Upgrade Strategy](#version-pinning-and-upgrade-strategy)
- [Shell Completions and Editor Setup](#shell-completions-and-editor-setup)
- [Initialising a Project](#initialising-a-project)
- [Environment Variables Reference](#environment-variables-reference)
- [Exercises](#exercises)
- [Further Reading](#further-reading)
- [Summary](#summary)
- [Next Module →](#next-module-)

---

## Overview

Before writing any OpenTofu configuration, your environment needs to be set up correctly. A well-configured environment prevents a whole category of issues: version mismatches between team members, provider plugin re-downloads on every run, and editor errors from missing language support.

This module covers:

- All installation methods (package managers, version managers, manual)
- How to pin and manage OpenTofu versions across a team
- Editor setup for productive HCL development
- What `tofu init` does and what files it creates
- Every environment variable that controls OpenTofu behaviour

↑ [Back to Table of Contents](#table-of-contents)

---

## Binary Installation Methods

### Package Managers

The fastest way to install OpenTofu on most systems.

**macOS (Homebrew)**
```bash
brew install opentofu
tofu version
```

**Debian / Ubuntu (apt)**
```bash
# Add the OpenTofu apt repository
curl -fsSL https://get.opentofu.org/install-opentofu.sh | sh -s -- --install-method deb
tofu version
```

**RHEL / Fedora / Amazon Linux (dnf/yum)**
```bash
curl -fsSL https://get.opentofu.org/install-opentofu.sh | sh -s -- --install-method rpm
tofu version
```

**Windows (winget)**
```powershell
winget install OpenTofu.OpenTofu
```

**Windows (Chocolatey)**
```powershell
choco install opentofu
```

> **Note:** Package manager versions may lag slightly behind the latest release. For teams that need exact version control, use a version manager.

### Version Managers

Version managers let you install multiple OpenTofu versions and switch between them — essential for teams working across projects with different `required_version` constraints.

**tofuenv** (recommended — OpenTofu-specific)

```bash
# Install tofuenv
git clone --depth=1 https://github.com/tofuutils/tofuenv.git ~/.tofuenv
echo 'export PATH="$HOME/.tofuenv/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Install a specific version
tofuenv install 1.8.0

# Install the latest release
tofuenv install latest

# Use a specific version globally
tofuenv use 1.8.0

# Pin a version for a specific directory
echo "1.8.0" > .opentofu-version
# tofuenv will auto-select this version when you're in this directory

# List installed versions
tofuenv list

# List available versions
tofuenv list-remote
```

**asdf** (polyglot version manager)

```bash
# Install the OpenTofu plugin for asdf
asdf plugin add opentofu https://github.com/virtualroot/asdf-opentofu.git

# Install a version
asdf install opentofu 1.8.0

# Set globally
asdf global opentofu 1.8.0

# Set per-project (creates .tool-versions)
asdf local opentofu 1.8.0
```

### Manual Installation (any platform)

```bash
# Download the binary (replace VERSION and OS/ARCH as needed)
VERSION="1.8.0"
ARCH="linux_amd64"  # or darwin_arm64, windows_amd64, etc.

curl -Lo tofu.zip "https://github.com/opentofu/opentofu/releases/download/v${VERSION}/tofu_${VERSION}_${ARCH}.zip"
unzip tofu.zip
chmod +x tofu
sudo mv tofu /usr/local/bin/

# Verify installation
tofu version
```

> **Security note:** Always verify the SHA256 checksum of downloaded binaries:
> ```bash
> curl -Lo tofu.zip.sha256sum "https://github.com/opentofu/opentofu/releases/download/v${VERSION}/tofu_${VERSION}_${ARCH}.zip.sha256sum"
> sha256sum -c tofu.zip.sha256sum
> ```

### Container Image

For CI/CD or sandboxed execution:

```bash
# Run a one-off tofu command in a container
docker run --rm -v "$(pwd):/workspace" -w /workspace \
  ghcr.io/opentofu/opentofu:1.8.0 \
  tofu plan
```

↑ [Back to Table of Contents](#table-of-contents)

---

## Version Pinning and Upgrade Strategy

Version mismatches are a common source of team friction. A consistent pinning strategy prevents "works on my machine" problems.

### `required_version` in `versions.tf`

Every project should declare the minimum acceptable OpenTofu version:

```hcl
# versions.tf
terraform {
  required_version = ">= 1.6, < 2.0"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
```

### Version Constraint Operators

| Operator | Meaning | Example | Matches |
|---|---|---|---|
| `=` | Exact version | `= 1.8.0` | Only 1.8.0 |
| `!=` | Not this version | `!= 1.7.0` | Anything except 1.7.0 |
| `>` | Greater than | `> 1.6.0` | 1.7.0, 1.8.0, ... |
| `>=` | Greater than or equal | `>= 1.6.0` | 1.6.0, 1.7.0, ... |
| `<` | Less than | `< 2.0.0` | 1.x.x |
| `<=` | Less than or equal | `<= 1.8.0` | Up to 1.8.0 |
| `~>` | Pessimistic (patch only) | `~> 1.8.0` | >= 1.8.0, < 1.9.0 |
| `~>` | Pessimistic (minor only) | `~> 1.8` | >= 1.8.0, < 2.0.0 |

### `.opentofu-version` File (tofuenv)

Create this file in your project root to pin the exact version for all team members using tofuenv:

```
1.8.0
```

tofuenv automatically reads this file when you are in the directory. Commit it to your repository.

### Upgrade Strategy

1. **Patch releases** (`1.8.0` → `1.8.1`): Safe to apply immediately; patch releases contain only bug fixes.
2. **Minor releases** (`1.8.x` → `1.9.0`): Read the changelog; test in a non-production workspace first.
3. **Major releases** (`1.x` → `2.0`): Treat as a full migration; expect breaking changes.

```bash
# Check for newer versions
tofuenv list-remote | head -10

# Upgrade tofuenv itself
cd ~/.tofuenv && git pull
```

↑ [Back to Table of Contents](#table-of-contents)

---

## Shell Completions and Editor Setup

### Shell Completions

Enable tab completion for `tofu` subcommands and flags:

```bash
# Bash
tofu -install-autocomplete
# Adds to ~/.bashrc: complete -C /usr/local/bin/tofu tofu
source ~/.bashrc

# Zsh
tofu -install-autocomplete
# Adds to ~/.zshrc
source ~/.zshrc

# Fish
# Not natively supported; use a wrapper plugin
```

### VS Code

Install the **HashiCorp Terraform** extension (it fully supports OpenTofu's HCL syntax):

```bash
code --install-extension hashicorp.terraform
```

**Recommended VS Code settings** (`settings.json`):

```json
{
  "[terraform]": {
    "editor.formatOnSave": true,
    "editor.defaultFormatter": "hashicorp.terraform"
  },
  "terraform.languageServer.enable": true,
  "terraform.validation.enableEnhancedValidation": true
}
```

The extension provides:
- Syntax highlighting for `.tf` and `.tofu` files
- Auto-completion for resource arguments and provider attributes
- Go-to-definition for variables and outputs
- Inline documentation from provider schemas
- Format on save using `tofu fmt`

### Vim / Neovim

```bash
# vim-plug: add to .vimrc
Plug 'hashivim/vim-terraform'
Plug 'vim-syntastic/syntastic'

# neovim with nvim-lspconfig: add terraform-ls
# Install terraform-ls binary, then configure:
require'lspconfig'.terraformls.setup{}
```

### `.editorconfig`

Add an `.editorconfig` file to your project root to enforce consistent formatting across editors:

```ini
root = true

[*.tf]
indent_style = space
indent_size = 2
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[*.tfvars]
indent_style = space
indent_size = 2
```

↑ [Back to Table of Contents](#table-of-contents)

---

## Initialising a Project

### What `tofu init` Does

Running `tofu init` in a directory performs several operations:

1. **Reads `versions.tf`** — identifies required providers and modules
2. **Downloads provider plugins** — fetches binaries from the registry to `.terraform/providers/`
3. **Configures the backend** — sets up state storage (local by default)
4. **Installs module sources** — downloads remote modules to `.terraform/modules/`
5. **Creates `.terraform.lock.hcl`** — records exact provider versions and checksums

### `.terraform/` Directory Contents

```
.terraform/
├── providers/
│   └── registry.terraform.io/
│       └── hashicorp/
│           └── local/
│               └── 2.5.1/
│                   └── linux_amd64/
│                       └── terraform-provider-local_v2.5.1_x5  # binary
├── modules/
│   └── modules.json
└── terraform.tfstate  # only for certain backends
```

> **Under the hood:** The `.terraform/providers/` directory is a content-addressable cache. The provider binary is named and versioned to prevent conflicts between different provider versions in the same system.

**Do NOT commit `.terraform/`** — add it to `.gitignore`:
```gitignore
.terraform/
*.tfstate
*.tfstate.backup
*.tfplan
```

### `.terraform.lock.hcl` — The Lock File

The lock file records the exact provider versions and their checksums for multiple platforms:

```hcl
# .terraform.lock.hcl
provider "registry.terraform.io/hashicorp/local" {
  version     = "2.5.1"
  constraints = "~> 2.5"
  hashes = [
    "h1:8bCOL0mQNjM/l5SvWBvhTkDXAHUx2NbBomXwWqLpqeE=",
    "zh:0af29ce2b7b5712319bf6424cb58d13b852bf9a777011a545fac99c7fdcdf561",
    # ... (one hash per platform)
  ]
}
```

**Always commit `.terraform.lock.hcl`**. It ensures:
- Every team member uses identical provider versions
- CI/CD uses the same providers as local development
- Security: checksums prevent supply-chain attacks

To update providers to newer versions (within constraints):

```bash
tofu init -upgrade
```

### Provider Plugin Cache

By default, `tofu init` downloads providers fresh into each project's `.terraform/` directory. For teams or CI systems with many projects, this is wasteful. Use a shared cache:

```bash
# Set globally in your shell profile
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
mkdir -p "$TF_PLUGIN_CACHE_DIR"
```

With the cache configured, `tofu init` copies providers from the cache instead of downloading them, dramatically speeding up init in CI/CD.

↑ [Back to Table of Contents](#table-of-contents)

---

## Environment Variables Reference

OpenTofu behaviour can be controlled entirely through environment variables — essential for CI/CD pipelines where interactive configuration is not possible.

### Core Variables

| Variable | Purpose | Example |
|---|---|---|
| `TF_LOG` | Set log verbosity level | `TF_LOG=DEBUG` |
| `TF_LOG_CORE` | Log verbosity for OpenTofu core only (1.5+) | `TF_LOG_CORE=TRACE` |
| `TF_LOG_PROVIDER` | Log verbosity for provider plugins only (1.5+) | `TF_LOG_PROVIDER=INFO` |
| `TF_LOG_PATH` | Write logs to a file instead of stderr | `TF_LOG_PATH=/tmp/tofu.log` |
| `TF_DATA_DIR` | Override the `.terraform/` directory location | `TF_DATA_DIR=/tmp/tf-data` |
| `TF_PLUGIN_CACHE_DIR` | Shared provider plugin cache directory | `TF_PLUGIN_CACHE_DIR=~/.tf-cache` |
| `TF_VAR_name` | Set a variable value (replaces `-var name=value`) | `TF_VAR_environment=prod` |

### CLI Argument Injection

`TF_CLI_ARGS_<command>` injects additional arguments to a specific command:

```bash
# Always run plan with -compact-warnings
export TF_CLI_ARGS_plan="-compact-warnings"

# Always run apply with -auto-approve in CI
export TF_CLI_ARGS_apply="-auto-approve"

# Always inject backend config for init
export TF_CLI_ARGS_init="-backend-config=backend.hcl"
```

### Log Levels

| Level | What is logged |
|---|---|
| `TRACE` | Everything — gRPC calls, internal operations (very verbose) |
| `DEBUG` | High-detail operational logs |
| `INFO` | Normal operational messages |
| `WARN` | Non-fatal issues |
| `ERROR` | Fatal errors only |
| `JSON` | Structured JSON logs (1.5+) |
| `OFF` | Disable all logging (default) |

```bash
# Debug a specific apply, writing logs to file
TF_LOG=DEBUG TF_LOG_PATH=/tmp/tofu-debug.log tofu apply
```

### OpenTofu-specific Variable Names

OpenTofu supports `TOFU_`-prefixed versions of all `TF_`-prefixed variables. Both are accepted:

```bash
TOFU_LOG=DEBUG     # same as TF_LOG=DEBUG
TOFU_DATA_DIR=...  # same as TF_DATA_DIR=...
```

The `TOFU_` prefix is preferred in new configurations to clearly distinguish from Terraform.

↑ [Back to Table of Contents](#table-of-contents)

---

## Exercises

### Exercise 1 — Easy: Install and Verify

1. Install OpenTofu using the method appropriate for your OS
2. Run `tofu version` and record the output
3. Run `tofu -help` and identify 5 subcommands you have not yet used
4. Enable shell completions and verify they work by pressing Tab after typing `tofu `

Expected output of `tofu version`:
```
OpenTofu v1.x.x
on linux_amd64
```

---

### Exercise 2 — Medium: tofuenv Multi-Version Setup

1. Install `tofuenv` using the instructions in this module
2. Install **two different versions** of OpenTofu: `1.7.0` and `1.8.0`
3. Create a directory `~/tofu-test/` and add a `.opentofu-version` file pinning version `1.7.0`
4. Navigate into the directory and run `tofu version` — confirm it shows 1.7.0
5. From outside the directory, run `tofu version` — confirm it shows your globally set version
6. Add a `versions.tf` with `required_version = ">= 1.8"` and try running `tofu init` in the `1.7.0`-pinned directory — observe the error
7. Explain in writing: why does OpenTofu enforce `required_version` and what would happen without it?

---

### Exercise 3 — Hard: Provider Cache Benchmark

1. Create two empty project directories: `project-a/` and `project-b/`
2. In each, create a `versions.tf` that requires the `local` and `random` providers
3. **Without** a plugin cache: run `tofu init` in both projects, measuring time with `time tofu init`
4. Configure `TF_PLUGIN_CACHE_DIR` pointing to a shared directory
5. Delete both `.terraform/` directories
6. Run `tofu init` again in both projects and measure the time
7. Compare the times and explain the difference
8. Inspect the cache directory contents — what is stored there and how is it structured?
9. Write a short analysis: when is the plugin cache most valuable (team size, CI/CD frequency, network bandwidth)?

↑ [Back to Table of Contents](#table-of-contents)

---

## Further Reading

- [OpenTofu Installation Docs](https://opentofu.org/docs/intro/install/) — Official install guide for all platforms
- [tofuenv GitHub](https://github.com/tofuutils/tofuenv) — Version manager for OpenTofu
- [asdf-opentofu Plugin](https://github.com/virtualroot/asdf-opentofu) — asdf integration for OpenTofu
- [HashiCorp Terraform VS Code Extension](https://marketplace.visualstudio.com/items?itemName=HashiCorp.terraform) — Works with OpenTofu HCL
- [OpenTofu Environment Variables](https://opentofu.org/docs/cli/config/environment-variables/) — Full reference
- [`.terraform.lock.hcl` Explained](https://opentofu.org/docs/language/files/dependency-lock/) — Lock file deep-dive

↑ [Back to Table of Contents](#table-of-contents)

---

## Summary

| Concept | Key Takeaway |
|---|---|
| Installation | Use package manager for simplicity; tofuenv for team version consistency |
| `required_version` | Always pin in `versions.tf`; use `~>` for safe minor-version upgrades |
| Lock file | Commit `.terraform.lock.hcl`; never commit `.terraform/` |
| Plugin cache | Set `TF_PLUGIN_CACHE_DIR` to speed up init in CI/CD |
| Editor | Install HashiCorp Terraform extension; enable format-on-save |
| `TF_LOG` | Set to `DEBUG` or `TRACE` when diagnosing problems |

↑ [Back to Table of Contents](#table-of-contents)

---

## Next Module →

**[Module 03 — Providers & Resources](../03-providers-and-resources/03-providers-and-resources.md)**

Learn how providers work, explore the `null`, `local`, and `random` providers in depth, and master every resource meta-argument.


---

<sub>© 2026 UncleJS & Course OpenTofu contributors — licensed under [CC BY-NC-SA 4.0](../../LICENSE).<br>
You may share and adapt this material for non-commercial purposes with attribution.<br>
SPDX-License-Identifier: CC-BY-NC-SA-4.0</sub>