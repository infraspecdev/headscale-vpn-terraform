module "headscale" {
  source = "../../"

  vpc_id           = var.vpc_id
  public_subnet_id = var.public_subnet_id
  ssh_key_name     = var.ssh_key_name
  allowed_ssh_cidr = var.allowed_ssh_cidr
  enable_headplane = true
  user_groups      = var.user_groups
  tags             = var.tags
}
