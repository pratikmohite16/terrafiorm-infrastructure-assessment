resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # GitHub OIDC
}

data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals { type = "Federated" identifiers = [aws_iam_openid_connect_provider.github.arn] }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.allowed_repos # e.g., ["repo:yourorg/aws-db-platform:*"]
    }
  }
}

resource "aws_iam_role" "gha_deploy" {
  name               = "${var.name}-gha-deploy"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_policy" "gha_perm" {
  name   = "${var.name}-gha-permissions"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { "Effect":"Allow", "Action":[
          "s3:*","dynamodb:*","ec2:*","rds:*","iam:PassRole","secretsmanager:*","logs:*","cloudwatch:*","elasticloadbalancing:*","acm:*","kms:*"
        ], "Resource":"*" }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.gha_deploy.name
  policy_arn = aws_iam_policy.gha_perm.arn
}

output "role_arn" { value = aws_iam_role.gha_deploy.arn }
