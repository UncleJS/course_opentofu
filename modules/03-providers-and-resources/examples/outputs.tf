output "env_config_paths" {
  description = "Map of environment name to config file path"
  value       = { for k, v in local_file.env_config : k => v.filename }
}

output "env_codenames" {
  description = "Map of environment name to generated codename"
  value       = { for k, v in random_pet.env_name : k => v.id }
}

output "index_path" {
  description = "Path to the master index file"
  value       = local_file.index.filename
}
