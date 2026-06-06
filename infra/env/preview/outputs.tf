output "preview_url" {
  value = "http://${data.terraform_remote_state.shared.outputs.preview_alb_dns_name}${local.preview_path}/"
}

output "preview_api_base_url" {
  value = "http://${data.terraform_remote_state.shared.outputs.preview_alb_dns_name}${local.preview_path}/api/v1"
}

output "auth_validation_mode" {
  value = "infrastructure-only until UI basename support and HTTPS preview hosts are added"
}
