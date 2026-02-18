output "headscale_public_ip" {
  description = "Public IP of the headscale server"
  value       = module.headscale.headscale_public_ip
}

output "headscale_url" {
  description = "URL of the headscale server"
  value       = module.headscale.headscale_url
}

output "headscale_instance_id" {
  description = "Instance ID of the headscale server"
  value       = module.headscale.headscale_instance_id
}

output "auth_key_ssm_prefix" {
  description = "SSM parameter prefix for auth keys"
  value       = module.headscale.auth_key_ssm_prefix
}

output "headplane_url" {
  description = "URL of the Headplane web UI"
  value       = module.headscale.headplane_url
}
