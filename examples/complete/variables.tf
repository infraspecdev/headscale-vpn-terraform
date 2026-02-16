variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "ami_id" {
  description = "AMI ID (Amazon Linux 2023)"
  type        = string
  default     = "ami-0317b0f0a0144b137"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for headscale server"
  type        = string
}

variable "ssh_key_name" {
  description = "AWS SSH key pair name"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed for SSH access (e.g. your IP/32)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "headscale_version" {
  description = "Headscale version to install"
  type        = string
  default     = "0.23.0"
}

variable "user_groups" {
  description = "Map of group name to users and allowed IPs. Use [\"*\"] for full access."
  type = map(object({
    users       = list(string)
    allowed_ips = list(string)
  }))
  default = {}
}

variable "tags" {
  description = "Map of tags to assign to resources"
  type        = map(string)
  default     = {}
}
