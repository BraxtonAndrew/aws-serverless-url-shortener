resource "aws_dynamodb_table" "this" {
  #checkov:skip=CKV_AWS_119:Encrypted at rest by default with an AWS-owned key; data is public URLs, so a customer-managed key adds cost without benefit

  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "short_code"

  attribute {
    name = "short_code"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }
}