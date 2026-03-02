## Bug 04 — Type Mismatch

**Error you will see:**
```
│ Error: Invalid default value for variable
│
│   on main.tf line 7, in variable "replica_count":
│    7:   default = "three"
│
│ This default value is not compatible with the variable's type constraint:
│ a number is required.
```

**What's wrong:** The variable `replica_count` is typed as `number`, but the default value `"three"` is a string that cannot be converted to a number.

**Fix:** Change the default to a numeric literal:
```hcl
default = 3
```

**Lesson:** OpenTofu's type system is strict. String-to-number conversion is attempted automatically (`"3"` → `3`), but non-numeric strings like `"three"` will always fail. Use `tofu console` to test type conversions:
```bash
tofu console
> tonumber("42")
42
> tonumber("three")
Error: Invalid function argument
```


---

<sub>© 2026 UncleJS & Course OpenTofu contributors — licensed under [CC BY-NC-SA 4.0](../../../../../LICENSE).<br>
You may share and adapt this material for non-commercial purposes with attribution.<br>
SPDX-License-Identifier: CC-BY-NC-SA-4.0</sub>