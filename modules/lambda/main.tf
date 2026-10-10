data "archive_file" "this" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.root}/lambda.zip"
}

resource "aws_lambda_function" "this" {
  #checkov:skip=CKV_AWS_115:Account concurrency limit is 10 and AWS requires 10 unreserved; API Gateway throttling caps traffic instead
  #checkov:skip=CKV_AWS_116:DLQs only apply to async invocations; API Gateway invokes synchronously and errors return to the caller
  #checkov:skip=CKV_AWS_117:Only calls the public DynamoDB endpoint; a VPC would add NAT cost with no security benefit
  #checkov:skip=CKV_AWS_272:Code signing is out of scope; the OIDC-restricted pipeline is the only deploy path
  #checkov:skip=CKV_AWS_173:Env vars hold no secrets (table name only) and are encrypted at rest with an AWS-managed key

  function_name = var.function_name
  role          = aws_iam_role.this.arn
  runtime       = "python3.13"
  handler       = "app.lambda_handler"

  filename         = data.archive_file.this.output_path
  source_code_hash = data.archive_file.this.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = var.table_name
    }
  }

  tracing_config {
    mode = "Active"
  }
}

resource "aws_iam_role" "this" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "dynamodb" {
  statement {
    effect    = "Allow"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem"]
    resources = [var.table_arn]
  }
}

resource "aws_iam_role_policy" "dynamodb" {
  name   = "dynamodb-access"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.dynamodb.json
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "xray" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}