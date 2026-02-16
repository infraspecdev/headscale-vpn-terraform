<!-- BEGIN_TF_DOCS -->
# terraform-aws-headscale

Terraform module to deploy a self-hosted [Headscale](https://github.com/juanfont/headscale) VPN server on AWS with automated user onboarding, ACL-based access control, and subnet routing.

## Features

- Single EC2 instance running both Headscale (coordination server) and Tailscale (subnet router)
- Automated user creation and auth key generation via `terraform apply`
- Auth keys stored in AWS SSM Parameter Store (SecureString)
- ACL policy with user groups for granular access control
- Subnet routing to access all private IPs in your VPC over VPN

## Project Structure

```
headscale-terraform-registry/
├── configs/                    # Configuration templates
│   ├── headscale_config.tpl   # Headscale server configuration template
│   └── user_data.tpl          # EC2 instance bootstrap script
├── scripts/                   # Automation scripts
│   └── create-user.sh         # User creation and auth key generation via SSM
├── examples/                  # Usage examples
│   ├── complete/              # Full configuration with all options
│   └── minimal/               # Minimal working configuration
├── main.tf                    # Core infrastructure (EC2, EIP, VPC lookup)
├── variables.tf               # Module input variables
├── outputs.tf                 # Module output values
├── iam.tf                     # IAM roles and policies for SSM access
├── users.tf                   # User provisioning via null_resource
├── security_groups.tf         # Network security group rules
└── versions.tf                # Terraform and provider version constraints
```

## Architecture

This module deploys a complete VPN solution using Headscale (open-source Tailscale control server) on a single EC2 instance:

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS VPC                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │               Headscale EC2 Instance                   │ │
│  │  ┌──────────────────┐  ┌─────────────────────────┐   │ │
│  │  │   Headscale      │  │   Tailscale             │   │ │
│  │  │   (Controller)   │◄─┤   (Subnet Router)       │   │ │
│  │  │   Port: 8080     │  │   Routes: VPC CIDR      │   │ │
│  │  └────────┬─────────┘  └─────────────────────────┘   │ │
│  │           │                                            │ │
│  │           │ Elastic IP (Public)                       │ │
│  └───────────┼────────────────────────────────────────────┘ │
│              │                                              │
│  ┌───────────▼──────────────┐                              │
│  │    Private Resources     │                              │
│  │  (RDS, EC2, EKS, etc.)   │                              │
│  └──────────────────────────┘                              │
└─────────────────────────────────────────────────────────────┘
                    ▲
                    │ VPN Connection (WireGuard)
                    │
         ┌──────────┴──────────┐
         │  Client Devices     │
         │  (Laptop, Mobile)   │
         │  w/ Tailscale       │
         └─────────────────────┘

External Services:
┌─────────────────────┐
│  AWS SSM Parameter  │  ← Auth keys stored as SecureStrings
│  Store              │
└─────────────────────┘
```

### Components:

1. **Headscale Server**: Open-source coordination server that manages VPN clients, assigns IPs, and enforces ACL policies
2. **Tailscale Client**: Acts as a subnet router on the same EC2 instance to forward traffic to private resources
3. **Security Groups**: Allow inbound connections on port 8080 (Headscale) and SSH from specified CIDR
4. **IAM Role**: Grants EC2 instance permissions to store/retrieve auth keys in SSM Parameter Store
5. **User Provisioning**: Automated via `null_resource` + SSM Run Command to create users and generate auth keys

## How It Works

### 1. Infrastructure Provisioning
- Terraform creates an EC2 instance in your specified public subnet
- An Elastic IP is allocated and associated with the instance for stable public access
- Security groups allow inbound traffic on port 8080 (Headscale API) and SSH
- IAM instance profile grants SSM permissions for remote command execution

### 2. Server Bootstrap (user\_data.tpl)
- Installs Headscale binary and creates systemd service
- Configures Headscale with the public IP and ACL policy
- Installs Tailscale client on the same instance
- Creates a `subnet-router` user and connects Tailscale to Headscale locally
- Enables IP forwarding and advertises VPC CIDR routes
- Deploys helper script for user creation via SSM

### 3. User Creation (create-user.sh)
- For each user defined in `user_groups`, Terraform triggers a `null_resource`
- The script uses AWS SSM Send Command to remotely execute user creation on the EC2
- Creates Headscale user, generates a reusable preauth key (365-day expiration)
- Stores the auth key securely in SSM Parameter Store as a SecureString

### 4. ACL Policy
- User groups are defined in Terraform variables
- ACL policy controls which users can access which IPs in the VPC
- Applied at Headscale server startup and enforced for all connections

### 5. Client Connection Flow
```
Client Device → Tailscale App → Headscale Server (Port 8080)
                                       ↓
                            Validates Auth Key
                                       ↓
                            Assigns VPN IP (100.64.x.x)
                                       ↓
                            Applies ACL Rules
                                       ↓
                     Routes traffic to subnet-router
                                       ↓
                            Forwards to VPC resources
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.0 |
| <a name="provider_null"></a> [null](#provider\_null) | ~> 3.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_headscale_security_group"></a> [headscale\_security\_group](#module\_headscale\_security\_group) | terraform-aws-modules/security-group/aws | ~> 5.3.0 |

## Resources

| Name | Type |
|------|------|
| [aws_eip.headscale](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_eip_association.headscale](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip_association) | resource |
| [aws_iam_instance_profile.headscale](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.headscale](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.headscale_ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.headscale_ssm_core](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_instance.headscale](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [null_resource.user](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [aws_vpc.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_ssh_cidr"></a> [allowed\_ssh\_cidr](#input\_allowed\_ssh\_cidr) | Your IP for SSH (e.g. 1.2.3.4/32) | `string` | n/a | yes |
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | AMI ID (Amazon Linux 2023) | `string` | `"ami-0317b0f0a0144b137"` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region for SSM parameter storage | `string` | `"ap-south-1"` | no |
| <a name="input_headscale_version"></a> [headscale\_version](#input\_headscale\_version) | Version of headscale to install on the server | `string` | `"0.23.0"` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type for the headscale server | `string` | `"t3.micro"` | no |
| <a name="input_public_subnet_id"></a> [public\_subnet\_id](#input\_public\_subnet\_id) | ID of the public subnet for the headscale EC2 instance | `string` | n/a | yes |
| <a name="input_ssh_key_name"></a> [ssh\_key\_name](#input\_ssh\_key\_name) | Name of the AWS SSH key pair for EC2 instance access | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Map of tags to assign to all resources | `map(string)` | `{}` | no |
| <a name="input_user_groups"></a> [user\_groups](#input\_user\_groups) | Map of group name to users and allowed IPs. Use ["*"] for full access. | <pre>map(object({<br/>    users       = list(string)<br/>    allowed_ips = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC where headscale server will be deployed | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_auth_key_ssm_prefix"></a> [auth\_key\_ssm\_prefix](#output\_auth\_key\_ssm\_prefix) | SSM parameter prefix where auth keys are stored |
| <a name="output_headscale_instance_id"></a> [headscale\_instance\_id](#output\_headscale\_instance\_id) | Instance ID of the headscale EC2 |
| <a name="output_headscale_public_ip"></a> [headscale\_public\_ip](#output\_headscale\_public\_ip) | Public IP of the headscale server |
| <a name="output_headscale_url"></a> [headscale\_url](#output\_headscale\_url) | URL of the headscale server |
<!-- END_TF_DOCS -->
