<!-- BEGIN_TF_DOCS -->
# Complete Example

Full Headscale VPN setup with multiple user groups and ACL-based access control.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_headscale"></a> [headscale](#module\_headscale) | ../../ | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_ssh_cidr"></a> [allowed\_ssh\_cidr](#input\_allowed\_ssh\_cidr) | CIDR allowed for SSH access (e.g. your IP/32) | `string` | n/a | yes |
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | AMI ID (Amazon Linux 2023) | `string` | `"ami-0317b0f0a0144b137"` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | `"ap-south-1"` | no |
| <a name="input_headscale_version"></a> [headscale\_version](#input\_headscale\_version) | Headscale version to install | `string` | `"0.23.0"` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type | `string` | `"t3.micro"` | no |
| <a name="input_public_subnet_id"></a> [public\_subnet\_id](#input\_public\_subnet\_id) | Public subnet ID for headscale server | `string` | n/a | yes |
| <a name="input_ssh_key_name"></a> [ssh\_key\_name](#input\_ssh\_key\_name) | AWS SSH key pair name | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Map of tags to assign to resources | `map(string)` | `{}` | no |
| <a name="input_user_groups"></a> [user\_groups](#input\_user\_groups) | Map of group name to users and allowed IPs. Use ["*"] for full access. | <pre>map(object({<br/>    users       = list(string)<br/>    allowed_ips = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_auth_key_ssm_prefix"></a> [auth\_key\_ssm\_prefix](#output\_auth\_key\_ssm\_prefix) | SSM parameter prefix for auth keys |
| <a name="output_headscale_instance_id"></a> [headscale\_instance\_id](#output\_headscale\_instance\_id) | Instance ID of the headscale server |
| <a name="output_headscale_public_ip"></a> [headscale\_public\_ip](#output\_headscale\_public\_ip) | Public IP of the headscale server |
| <a name="output_headscale_url"></a> [headscale\_url](#output\_headscale\_url) | URL of the headscale server |
<!-- END_TF_DOCS -->
