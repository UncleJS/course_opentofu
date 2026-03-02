# Ensure output directory exists (using null_resource + local-exec)
resource "null_resource" "output_dir" {
  triggers = {
    dir = var.output_dir
  }
  provisioner "local-exec" {
    command = "mkdir -p ${var.output_dir}"
  }
}

# Generate a random pet name per environment
resource "random_pet" "env_name" {
  for_each  = var.environments
  length    = 2
  separator = "-"
  prefix    = each.key

  keepers = {
    environment = each.key
  }
}

# Create one config file per environment
resource "local_file" "env_config" {
  for_each   = var.environments
  depends_on = [null_resource.output_dir]

  filename = "${var.output_dir}/${each.key}-config.txt"
  content  = <<-EOT
    Environment : ${each.key}
    Description : ${each.value}
    Codename    : ${random_pet.env_name[each.key].id}
  EOT

  file_permission = "0644"
}

# Create a master index file listing all environments
resource "local_file" "index" {
  depends_on = [local_file.env_config]
  filename   = "${var.output_dir}/index.txt"

  content = templatefile("${path.module}/templates/index.tpl", {
    environments = var.environments
    pet_names    = { for k, v in random_pet.env_name : k => v.id }
    files        = { for k, v in local_file.env_config : k => v.filename }
  })
}
