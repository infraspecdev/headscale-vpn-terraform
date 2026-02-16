variable "ami_id" {
  description = "AMI ID (Amazon Linux 2023)"
  type        = string
  default     = "ami-0317b0f0a0144b137"
}

variable "vpc_id" {
  description = "ID of the VPC where headscale server will be deployed"
  type        = string
}

variable "public_subnet_id" {
  description = "ID of the public subnet for the headscale EC2 instance"
  type        = string
}

variable "ssh_key_name" {
  description = "Name of the AWS SSH key pair for EC2 instance access"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "Your IP for SSH (e.g. 1.2.3.4/32)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the headscale server"
  type        = string
  default     = "t3.micro"
}

variable "headscale_version" {
  description = "Version of headscale to install on the server"
  type        = string
  default     = "0.23.0"
}

variable "aws_region" {
  description = "AWS region for SSM parameter storage"
  type        = string
  default     = "ap-south-1"
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
  description = "Map of tags to assign to all resources"
  type        = map(string)
  default     = {}
}
