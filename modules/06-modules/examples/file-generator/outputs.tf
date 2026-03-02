output "file_paths" {
  description = "Map of file key to absolute path of the created file"
  value       = { for k, v in local_file.files : k => v.filename }
}

output "file_count" {
  description = "Number of files created by this module"
  value       = length(local_file.files)
}
