<!-- BEGIN_TF_DOCS -->
# Minimal Example

Basic Headscale VPN setup with a single user group.

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
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | `"ap-south-1"` | no |
| <a name="input_public_subnet_id"></a> [public\_subnet\_id](#input\_public\_subnet\_id) | Public subnet ID for headscale server | `string` | n/a | yes |
| <a name="input_ssh_key_name"></a> [ssh\_key\_name](#input\_ssh\_key\_name) | AWS SSH key pair name | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_user_groups"></a> [user\_groups](#input\_user\_groups) | Map of group name to users and allowed IPs. Use ["*"] for full access. | <pre>map(object({<br/>    users       = list(string)<br/>    allowed_ips = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_headscale_public_ip"></a> [headscale\_public\_ip](#output\_headscale\_public\_ip) | Public IP of the headscale server |
| <a name="output_headscale_url"></a> [headscale\_url](#output\_headscale\_url) | URL of the headscale server |
<!-- END_TF_DOCS -->
