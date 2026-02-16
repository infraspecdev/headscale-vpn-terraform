output "headscale_public_ip" {
  description = "Public IP of the headscale server"
  value       = module.headscale.headscale_public_ip
}

output "headscale_url" {
  description = "URL of the headscale server"
  value       = module.headscale.headscale_url
}
