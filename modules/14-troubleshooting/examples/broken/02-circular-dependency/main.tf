# ── BUG: circular dependency via depends_on ───────────────────────────────
# resource A depends_on B, and B depends_on A → cycle
# Error: Cycle: null_resource.a, null_resource.b
#
# FIX: remove the depends_on from null_resource.b (it is unnecessary)

resource "local_file" "shared" {
  filename        = "/tmp/tofu-broken-02/shared.txt"
  content         = "shared resource\n"
  file_permission = "0644"
}

resource "null_resource" "a" {
  triggers = { id = local_file.shared.id }

  provisioner "local-exec" {
    command = "echo 'resource A'"
  }

  # This explicit depends_on creates the second edge of the cycle
  # BUG IS HERE ↓
  depends_on = [null_resource.b]
}

resource "null_resource" "b" {
  triggers = { id = local_file.shared.id }

  provisioner "local-exec" {
    command = "echo 'resource B'"
  }

  depends_on = [null_resource.a]
}
