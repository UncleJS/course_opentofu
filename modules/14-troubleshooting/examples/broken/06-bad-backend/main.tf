resource "local_file" "example" {
  filename        = "/tmp/tofu-broken-06/example.txt"
  content         = "This config has a broken backend.\n"
  file_permission = "0644"
}
