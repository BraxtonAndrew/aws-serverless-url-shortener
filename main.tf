#################### Database ####################
resource "aws_dynamodb_table" "url_shortener_links" {
  name         = "url-shortener-links"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "short_code"

  attribute {
    name = "short_code"
    type = "S"
  }

}

#################### IAM ####################
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "url_shortener_lambda_role" {
  name               = "url-shortener-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "url_shortener_lambda_role_policy_document" {
  statement {
    effect    = "Allow"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem"]
    resources = [aws_dynamodb_table.url_shortener_links.arn]
  }
}

resource "aws_iam_role_policy" "url_shortener_lambda_policy" {
  name   = "lambda-policy"
  role   = aws_iam_role.url_shortener_lambda_role.id
  policy = data.aws_iam_policy_document.url_shortener_lambda_role_policy_document.json
}