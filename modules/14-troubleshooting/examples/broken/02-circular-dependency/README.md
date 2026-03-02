## Bug 02 — Circular Dependency

**Error you will see:**
```
│ Error: Cycle: null_resource.a, null_resource.b
│
│ OpenTofu detected a cycle in the dependency graph. The resources
│ listed above form a dependency cycle that prevents a valid execution plan.
```

**What's wrong:** `null_resource.a` declares `depends_on = [null_resource.b]` **and** `null_resource.b` declares `depends_on = [null_resource.a]`. This creates a cycle — neither resource can be created first.

**Fix:** Remove the `depends_on = [null_resource.b]` from `null_resource.a`. Both resources only need `local_file.shared` to exist first (which is already an implicit dependency via `triggers`).

**Lesson:** Use `depends_on` only for truly necessary ordering constraints. Over-using it (especially between sibling resources) is the primary cause of cycles. Prefer implicit references — if resource A uses an attribute from resource B, OpenTofu already knows B must come first.


---

<sub>© 2026 UncleJS & Course OpenTofu contributors — licensed under [CC BY-NC-SA 4.0](../../../../../LICENSE).<br>
You may share and adapt this material for non-commercial purposes with attribution.<br>
SPDX-License-Identifier: CC-BY-NC-SA-4.0</sub>