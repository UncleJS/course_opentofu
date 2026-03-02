# ── BUG: count and for_each used together on the same resource ────────────
# Error: Invalid combination of "count" and "for_each"
#
# FIX: remove the `count` meta-argument — for_each alone handles the loop

variable "configs" {
  type    = map(string)
  default = { "a" = "alpha", "b" = "beta" }
}

resource "local_file" "multi" {
  # BUG IS HERE ↓ — cannot use both count AND for_each
  count    = 2
  for_each = var.configs

  filename        = "/tmp/tofu-broken-05/${each.key}.txt"
  content         = each.value
  file_permission = "0644"
}
