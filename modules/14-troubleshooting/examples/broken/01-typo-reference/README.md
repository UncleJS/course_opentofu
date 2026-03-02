## Bug 01 — Typo in Attribute Reference

**Error you will see:**
```
│ Error: Unsupported attribute
│
│   on main.tf line 17:
│   17:   content = local_file.source.contnet
│
│ This object does not have an attribute named "contnet".
```

**What's wrong:** `contnet` is a typo — the correct attribute is `content`.

**Fix:** Change line 17 to:
```hcl
content = local_file.source.content
```

**Lesson:** OpenTofu attribute names are case-sensitive and must match exactly what the provider exports. Use `tofu state show resource_type.name` or check the provider documentation to find the correct attribute names.


---

<sub>© 2026 UncleJS & Course OpenTofu contributors — licensed under [CC BY-NC-SA 4.0](../../../../../LICENSE).<br>
You may share and adapt this material for non-commercial purposes with attribution.<br>
SPDX-License-Identifier: CC-BY-NC-SA-4.0</sub>