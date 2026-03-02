# ── BUG: attribute name typo ──────────────────────────────────────────────
# The output references `.contnet` instead of `.content`
# Error: Unsupported attribute
#
# FIX: change `contnet` → `content` on line 17

resource "local_file" "source" {
  filename        = "/tmp/tofu-broken-01/source.txt"
  content         = "Hello from the source file!\n"
  file_permission = "0644"
}

resource "local_file" "copy" {
  filename        = "/tmp/tofu-broken-01/copy.txt"
  file_permission = "0644"

  # BUG IS HERE ↓ — attribute name is misspelled
  content = local_file.source.contnet
}
