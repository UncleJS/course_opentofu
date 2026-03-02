## Bug 05 — Invalid Combination of `count` and `for_each`

**Error you will see:**
```
│ Error: Invalid combination of "count" and "for_each"
│
│   on main.tf line 13, in resource "local_file" "multi":
│   13:   count    = 2
│
│ The "count" and "for_each" meta-arguments are mutually exclusive.
```

**What's wrong:** `count` and `for_each` are mutually exclusive meta-arguments — you can only use one or the other on any given resource.

**Fix:** Remove `count = 2` (keep `for_each`):
```hcl
resource "local_file" "multi" {
  for_each = var.configs

  filename        = "/tmp/tofu-broken-05/${each.key}.txt"
  content         = each.value
  file_permission = "0644"
}
```

**Lesson:**
- Use `count` when you want N identical resources (or 0/1 for conditional resources)
- Use `for_each` when each resource needs a distinct identity/key (map or set)
- Never combine them — OpenTofu has no way to resolve the ambiguity


---

<sub>© 2026 UncleJS & Course OpenTofu contributors — licensed under [CC BY-NC-SA 4.0](../../../../../LICENSE).<br>
You may share and adapt this material for non-commercial purposes with attribution.<br>
SPDX-License-Identifier: CC-BY-NC-SA-4.0</sub>