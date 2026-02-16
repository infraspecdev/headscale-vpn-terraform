module "headscale" {
  source = "../../"

  ami_id            = var.ami_id
  vpc_id            = var.vpc_id
  public_subnet_id  = var.public_subnet_id
  ssh_key_name      = var.ssh_key_name
  allowed_ssh_cidr  = var.allowed_ssh_cidr
  aws_region        = var.aws_region
  instance_type     = var.instance_type
  headscale_version = var.headscale_version
  user_groups       = var.user_groups
  tags              = var.tags
}
