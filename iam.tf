resource "aws_iam_role" "headscale" {
  name = "headscale-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "headscale_ssm" {
  name = "headscale-ssm-write"
  role = aws_iam_role.headscale.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssm:PutParameter",
        "ssm:GetParameter",
        "ssm:DeleteParameter"
      ]
      Resource = "arn:aws:ssm:*:*:parameter/headscale/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "headscale_ssm_core" {
  role       = aws_iam_role.headscale.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "headscale" {
  name = "headscale-server-profile"
  role = aws_iam_role.headscale.name
}
