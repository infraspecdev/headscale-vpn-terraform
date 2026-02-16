data "aws_vpc" "selected" {
  id = var.vpc_id
}

locals {
  acl_policy = jsonencode({
    groups = { for group, config in var.user_groups : "group:${group}" => config.users }
    acls = concat(
      [for group, config in var.user_groups : {
        action = "accept"
        src    = ["group:${group}"]
        dst    = [for ip in config.allowed_ips : ip == "*" ? "*:*" : "${ip}:*"]
      }],
      [{
        action = "accept"
        src    = ["subnet-router"]
        dst    = ["*:*"]
      }]
    )
  })
}

resource "aws_eip" "headscale" {
  domain = "vpc"
  tags   = merge(var.tags, { Name = "headscale-eip" })
}

resource "aws_instance" "headscale" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [module.headscale_security_group.security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.headscale.name
  source_dest_check      = false

  user_data = templatefile("${path.module}/configs/user_data.tpl", {
    HEADSCALE_VERSION = var.headscale_version
    VPC_CIDR          = data.aws_vpc.selected.cidr_block
    ACL_POLICY        = local.acl_policy
    HEADSCALE_CONFIG = templatefile("${path.module}/configs/headscale_config.tpl", {
      HEADSCALE_IP = aws_eip.headscale.public_ip
    })
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = merge(var.tags, { Name = "headscale-server" })
}

resource "aws_eip_association" "headscale" {
  instance_id   = aws_instance.headscale.id
  allocation_id = aws_eip.headscale.id
}
