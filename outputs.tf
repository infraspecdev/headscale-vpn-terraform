output "headscale_public_ip" {
  description = "Public IP of the headscale server"
  value       = aws_eip.headscale.public_ip
}

output "headscale_url" {
  description = "URL of the headscale server"
  value       = "http://${aws_eip.headscale.public_ip}:8080"
}

output "headscale_instance_id" {
  description = "Instance ID of the headscale EC2"
  value       = aws_instance.headscale.id
}

output "auth_key_ssm_prefix" {
  description = "SSM parameter prefix where auth keys are stored"
  value       = "/headscale/users"
}
