data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "github_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:BraxtonAndrew/aws-serverless-url-shortener:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "url-shortener-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json
}

data "aws_iam_policy_document" "github_actions_permissions" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::braxton-terraform-state-2026"]
  }

  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::braxton-terraform-state-2026/url-shortener/*"]
  }

  statement {
    actions   = ["dynamodb:*"]
    resources = ["arn:aws:dynamodb:us-east-1:${data.aws_caller_identity.current.account_id}:table/url-shortener-*"]
  }

  statement {
    actions   = ["lambda:*"]
    resources = ["arn:aws:lambda:us-east-1:${data.aws_caller_identity.current.account_id}:function:url-shortener*"]
  }

  statement {
    actions   = ["iam:*"]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/url-shortener-lambda*"]
  }

  statement {
    actions = ["apigateway:*"]
    resources = [
      "arn:aws:apigateway:us-east-1::/apis",
      "arn:aws:apigateway:us-east-1::/apis/*",
      "arn:aws:apigateway:us-east-1::/tags/*"
    ]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "url-shortener-pipeline-permissions"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}