## Bug 06 — Bad Backend Path

**Error you will see (during `tofu init`):**
```
│ Error: Failed to get existing workspaces
│
│ error listing workspaces: read /tmp: is a directory
```

Or on some systems:
```
│ Error: Error opening backend
│ The configured backend could not be opened: stat /tmp: is a directory
```

**What's wrong:** The `backend "local"` block sets `path = "/tmp"`. The local backend expects `path` to point to a **file** where the state JSON will be written — not a directory.

**Fix:** Change `path` in `versions.tf` to a full file path:
```hcl
backend "local" {
  path = "/tmp/tofu-broken-06/terraform.tfstate"
}
```

Then run `tofu init -reconfigure` to reinitialise with the corrected backend.

**Lesson:** Backend errors typically surface at `tofu init` time, before any plan or apply. Always run `tofu init` after changing any `backend {}` block. The `-reconfigure` flag forces OpenTofu to re-read the backend config even if it was previously initialised.


---

<sub>© 2026 UncleJS & Course OpenTofu contributors — licensed under [CC BY-NC-SA 4.0](../../../../../LICENSE).<br>
You may share and adapt this material for non-commercial purposes with attribution.<br>
SPDX-License-Identifier: CC-BY-NC-SA-4.0</sub>