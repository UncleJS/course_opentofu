## Bug 03 — Missing Required Variable

**Error you will see:**
```
│ Error: No value for required variable
│
│   on main.tf line 14, in variable "owner_team":
│   14: variable "owner_team" {
│
│ The root module input variable "owner_team" is not set, and has no default value.
│ Use a -var or -var-file command line argument to provide a value for this variable.
```

**What's wrong:** `var.owner_team` is declared without a `default` value, making it required. It is never supplied via `-var`, `-var-file`, or `TF_VAR_owner_team`.

**Fix option A** — add a default:
```hcl
variable "owner_team" {
  description = "Team responsible for this project."
  type        = string
  default     = "platform"
}
```

**Fix option B** — pass it at runtime:
```bash
tofu plan -var="owner_team=platform"
# or
export TF_VAR_owner_team="platform"
tofu plan
```

**Lesson:** Every variable without a `default` is a required input. Document required variables clearly and consider whether a sensible default exists before making a variable required.


---

<sub>© 2026 UncleJS & Course OpenTofu contributors — licensed under [CC BY-NC-SA 4.0](../../../../../LICENSE).<br>
You may share and adapt this material for non-commercial purposes with attribution.<br>
SPDX-License-Identifier: CC-BY-NC-SA-4.0</sub>