# OpenTofu: Beginner to Advanced

<!-- SPDX-License-Identifier: CC-BY-NC-SA-4.0 -->

[![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)
[![OpenTofu](https://img.shields.io/badge/OpenTofu-%E2%89%A51.6-blue?logo=opentofu)](https://opentofu.org)
[![Provider](https://img.shields.io/badge/Provider-local%20%2F%20null%20%2F%20random-green)](https://registry.terraform.io)
[![Modules](https://img.shields.io/badge/Modules-14-orange)](./modules/)
[![Level](https://img.shields.io/badge/Level-Beginner%20%E2%86%92%20Advanced-purple)](./modules/)
[![Contributions Welcome](https://img.shields.io/badge/Contributions-Welcome-brightgreen)](./CONTRIBUTING.md)

A comprehensive, hands-on course taking you from absolute beginner to advanced practitioner with [OpenTofu](https://opentofu.org) — the open-source Infrastructure as Code tool.

All examples are **provider-agnostic** (using `local`, `null`, and `random` providers) — no cloud account required.

---

## Table of Contents

- [Course Overview](#course-overview)
- [Who Is This Course For?](#who-is-this-course-for)
- [Prerequisites](#prerequisites)
- [How to Use This Course](#how-to-use-this-course)
- [Repository Structure](#repository-structure)
- [Modules](#modules)
- [Glossary](#glossary)
- [Quick Start](#quick-start)
- [Contributing](#contributing)
- [License](#license)

---

## Course Overview

This course teaches Infrastructure as Code (IaC) using OpenTofu — a community-driven, open-source fork of Terraform maintained under the Linux Foundation. You will learn how to:

- Declare, plan, and apply infrastructure configurations using HCL
- Manage state, backends, workspaces, and remote state sharing
- Build reusable modules and advanced expression patterns
- Test, validate, and troubleshoot OpenTofu configurations
- Integrate OpenTofu into CI/CD pipelines
- Apply production-grade patterns including imports, refactors, and health checks

The course is structured to be **self-contained**: every concept is explained with theory, illustrated with code examples, and reinforced with exercises of escalating difficulty.

↑ [Back to Table of Contents](#table-of-contents)

---

## Who Is This Course For?

| Persona | Starting Point | Recommended Path |
|---|---|---|
| **Sysadmin / Ops** | Comfortable with CLI, new to IaC | Modules 01 → 14 in order |
| **Developer** | Familiar with code, new to infrastructure | Skim 01–02, focus 03–12 |
| **DevOps / Platform Engineer** | Some Terraform/IaC experience | Start at 05, revisit earlier modules as needed |
| **Team Lead / Architect** | Evaluating OpenTofu for a team | Modules 01, 05, 06, 09, 10, 12 |

↑ [Back to Table of Contents](#table-of-contents)

---

## Prerequisites

- Basic command-line (terminal) familiarity
- A text editor (VS Code recommended)
- Git installed
- No cloud account required — all exercises use local providers
- No prior Terraform or OpenTofu experience needed for Modules 01–04

↑ [Back to Table of Contents](#table-of-contents)

---

## How to Use This Course

1. **Clone this repository** and work through modules in numeric order
2. **Read the README** for each module before opening any `.tf` files
3. **Run the examples** in the `examples/` directory of each module
4. **Complete the exercises** — there are three per module (Easy / Medium / Hard)
5. **Refer to the [Glossary](./GLOSSARY.md)** whenever you encounter an unfamiliar term
6. **Use Module 13 (Healthcheck)** to validate your environment before starting
7. **Use Module 14 (Troubleshooting)** when something goes wrong

### Suggested learning pace
- Beginner modules (01–04): ~3 hours total
- Intermediate modules (05–08, 13–14): ~6 hours total
- Advanced modules (09–12): ~6 hours total

↑ [Back to Table of Contents](#table-of-contents)

---

## Repository Structure

```
course_opentofu/
├── README.md                          # This file
├── LICENSE                            # CC BY-NC-SA 4.0
├── GLOSSARY.md                        # ~60 IaC / OpenTofu terms
└── modules/
    ├── 01-introduction/
    │   ├── README.md                  # Theory + exercises
    │   └── examples/                  # Runnable .tf files
    ├── 02-installation/
    ├── 03-providers-and-resources/
    ├── 04-variables-and-outputs/
    ├── 05-state-management/
    ├── 06-modules/
    │   └── examples/
    │       └── file-generator/        # Reusable child module
    ├── 07-workspaces/
    ├── 08-functions-and-expressions/
    ├── 09-backends-and-remote-state/
    ├── 10-cicd-integration/
    ├── 11-testing/
    ├── 12-advanced-patterns/
    ├── 13-healthcheck/
    └── 14-troubleshooting/
        └── examples/
            └── broken/                # Intentionally broken configs
```

↑ [Back to Table of Contents](#table-of-contents)

---

## Modules

| # | Module | Difficulty | Est. Time | Topics |
|---|---|---|---|---|
| [01](./modules/01-introduction/) | Introduction to OpenTofu | ![Beginner](https://img.shields.io/badge/Beginner-green) | 45 min | IaC concepts, OpenTofu vs Terraform, DAG internals, HCL primer |
| [02](./modules/02-installation/) | Installation & Setup | ![Beginner](https://img.shields.io/badge/Beginner-green) | 30 min | Install methods, tofuenv, editor setup, environment variables |
| [03](./modules/03-providers-and-resources/) | Providers & Resources | ![Beginner](https://img.shields.io/badge/Beginner-green) | 60 min | null/local/random providers, meta-arguments, data sources |
| [04](./modules/04-variables-and-outputs/) | Variables & Outputs | ![Beginner](https://img.shields.io/badge/Beginner-green) | 60 min | Types, validation, sensitive values, locals, complex patterns |
| [05](./modules/05-state-management/) | State Management | ![Intermediate](https://img.shields.io/badge/Intermediate-yellow) | 90 min | State internals, drift, backends, state ops, surgery |
| [06](./modules/06-modules/) | Modules | ![Intermediate](https://img.shields.io/badge/Intermediate-yellow) | 75 min | Sources, versioning, composition, for_each on modules |
| [07](./modules/07-workspaces/) | Workspaces | ![Intermediate](https://img.shields.io/badge/Intermediate-yellow) | 45 min | Workspace commands, per-workspace config, limitations |
| [08](./modules/08-functions-and-expressions/) | Functions & Expressions | ![Intermediate](https://img.shields.io/badge/Intermediate-yellow) | 75 min | All built-in functions, templatefile, dynamic blocks, try/can |
| [09](./modules/09-backends-and-remote-state/) | Backends & Remote State | ![Advanced](https://img.shields.io/badge/Advanced-red) | 90 min | Backend types, S3 pattern, remote state, encryption at rest |
| [10](./modules/10-cicd-integration/) | CI/CD Integration | ![Advanced](https://img.shields.io/badge/Advanced-red) | 90 min | GitOps workflow, GitHub Actions, GitLab CI, drift detection |
| [11](./modules/11-testing/) | Testing | ![Advanced](https://img.shields.io/badge/Advanced-red) | 90 min | tofu test, mock providers, tflint, Terratest, test pyramid |
| [12](./modules/12-advanced-patterns/) | Advanced Patterns | ![Advanced](https://img.shields.io/badge/Advanced-red) | 120 min | moved/import/check blocks, ephemeral resources, scale patterns |
| [13](./modules/13-healthcheck/) | Healthcheck | ![Intermediate](https://img.shields.io/badge/Intermediate-yellow) | 45 min | Pre-flight checklist, healthcheck script, state integrity |
| [14](./modules/14-troubleshooting/) | Troubleshooting | ![Intermediate](https://img.shields.io/badge/Intermediate-yellow) | 60 min | Debug logs, error table, state recovery, broken configs |

↑ [Back to Table of Contents](#table-of-contents)

---

## Glossary

A full reference of ~60 terms covering IaC fundamentals, HCL syntax, OpenTofu internals, state, modules, backends, CI/CD, and testing.

→ **[Open the Glossary](./GLOSSARY.md)**

↑ [Back to Table of Contents](#table-of-contents)

---

## Quick Start

```bash
# 1. Install OpenTofu (see Module 02 for full options)
brew install opentofu        # macOS
# or
apt install opentofu         # Debian/Ubuntu

# 2. Clone this repo
git clone https://github.com/your-org/course_opentofu.git
cd course_opentofu

# 3. Run the first example
cd modules/03-providers-and-resources/examples
tofu init
tofu plan
tofu apply
tofu destroy
```

↑ [Back to Table of Contents](#table-of-contents)

---

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a branch: `git checkout -b feat/your-improvement`
3. Follow the existing module structure and badge conventions
4. Ensure all `.tf` files pass `tofu fmt` and `tofu validate`
5. Open a Pull Request with a clear description

↑ [Back to Table of Contents](#table-of-contents)

---

## License

This course is licensed under the **Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License**.

[![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)

You are free to share and adapt this material for non-commercial purposes, provided you give appropriate credit and distribute any derivative works under the same license.

→ [Full license text](./LICENSE.md)

↑ [Back to Table of Contents](#table-of-contents)

---

<sub>© 2026 UncleJS & Course OpenTofu contributors — licensed under [CC BY-NC-SA 4.0](LICENSE.md).<br>
You may share and adapt this material for non-commercial purposes with attribution.<br>
SPDX-License-Identifier: CC-BY-NC-SA-4.0</sub>
