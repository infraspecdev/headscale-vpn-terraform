# Flatten user_groups into individual users for creation
locals {
  all_users = flatten([
    for group, config in var.user_groups : [
      for user in config.users : user
    ]
  ])
}

resource "null_resource" "user" {
  for_each = toset(local.all_users)

  depends_on = [aws_eip_association.headscale]

  triggers = {
    username     = each.key
    headscale_ip = aws_eip.headscale.public_ip
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/scripts/create-user.sh"

    environment = {
      INSTANCE_ID = aws_instance.headscale.id
      USERNAME    = each.key
      AWS_REGION  = var.aws_region
    }
  }
}
