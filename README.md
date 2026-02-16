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

### 2. Server Bootstrap (user_data.tpl)
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

## Usage

```hcl
module "headscale" {
  source  = "infraspecdev/headscale/aws"
  version = "~> 1.0"

  vpc_id               = "vpc-xxxxxxxxx"
  public_subnet_id     = "subnet-xxxxxxxxx"
  vpc_cidr             = "10.0.0.0/16"
  ssh_key_name         = "my-key"
  ssh_private_key_path = "/tmp/my-key.pem"
  allowed_ssh_cidr     = "1.2.3.4/32"
  aws_region           = "ap-south-1"

  user_groups = {
    full_access = {
      users       = ["rahul"]
      allowed_ips = ["*"]
    }
    limited_access = {
      users       = ["dev1"]
      allowed_ips = ["10.0.1.5/32"]
    }
  }
}
```

## Getting Access to VPN

### Prerequisites

1. **AWS CLI**: Ensure AWS CLI is installed and configured with credentials
   ```bash
   aws --version
   aws configure  # If not already configured
   ```

2. **IAM Permissions**: Your AWS user/role needs permissions to:
   - Read SSM parameters: `ssm:GetParameter`
   - Decrypt SecureStrings: `kms:Decrypt`

3. **Network Access**: Ensure your network allows outbound connections to the Headscale server IP on port 8080

### Step-by-Step Connection Guide

#### 1. Install Tailscale Client

**macOS:**
```bash
# Via Homebrew
brew install tailscale

# Or download from https://tailscale.com/download/mac
```

**Linux (Ubuntu/Debian):**
```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

**Windows:**
Download installer from [https://tailscale.com/download/windows](https://tailscale.com/download/windows)

**iOS/Android:**
Install the Tailscale app from App Store or Google Play

#### 2. Retrieve Your Authentication Key

Your username must match one of the users defined in the `user_groups` variable during Terraform deployment.

```bash
# Replace <your-username> with your actual username
# Replace <region> with your AWS region (e.g., ap-south-1)
aws ssm get-parameter \
  --name "/headscale/users/<your-username>/authkey" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text \
  --region <region>
```

Example:
```bash
aws ssm get-parameter \
  --name "/headscale/users/rahul/authkey" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text \
  --region ap-south-1
```

**Troubleshooting Key Retrieval:**
- If you get "ParameterNotFound", verify your username is spelled correctly and matches the Terraform configuration
- If you get permission errors, ask your AWS admin to grant you `ssm:GetParameter` access for `/headscale/users/<your-username>/*`

#### 3. Get the Headscale Server IP

Retrieve the public IP from Terraform outputs:
```bash
terraform output headscale_public_ip
```

Or find the Elastic IP in AWS Console → EC2 → Elastic IPs → Filter by "headscale-eip"

#### 4. Connect to the VPN

**macOS/Linux:**
```bash
sudo tailscale up \
  --login-server=http://<HEADSCALE_IP>:8080 \
  --authkey=<YOUR_AUTH_KEY> \
  --accept-routes
```

**Example:**
```bash
sudo tailscale up \
  --login-server=http://13.233.45.67:8080 \
  --authkey=abc123def456... \
  --accept-routes
```

**Windows:**
1. Open Tailscale app
2. Click Settings → Use custom coordination server
3. Enter: `http://<HEADSCALE_IP>:8080`
4. Paste your auth key when prompted
5. Enable "Accept subnet routes"

**Important Flags:**
- `--accept-routes`: Required to access VPC private resources through the subnet router
- `--login-server`: Points to your self-hosted Headscale server instead of Tailscale's servers

#### 5. Verify Connection

Check your VPN status:
```bash
tailscale status
```

You should see:
- Your device with a `100.64.x.x` IP address
- The subnet-router with advertised routes

Test connectivity to a private resource:
```bash
# Replace with an actual private IP in your VPC
ping 10.0.1.50
```

Check which routes are active:
```bash
tailscale status --json | jq '.Peer[] | select(.HostName=="subnet-router") | .PrimaryRoutes'
```

### Access Control

Your access to VPC resources is controlled by the ACL policy defined in `user_groups`:

- **full_access group**: Can access all IPs (`*`)
- **limited_access group**: Can only access specific IPs defined in `allowed_ips`

If you cannot reach a resource, verify:
1. Your user group membership in Terraform configuration
2. The `allowed_ips` list for your group
3. Security groups on the target AWS resource allow traffic from the Headscale instance

### Disconnecting

To disconnect from the VPN:
```bash
sudo tailscale down
```

To reconnect later, simply run `tailscale up` again (no need for auth key if not expired)

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
