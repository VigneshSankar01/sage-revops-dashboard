# ========== S3 BUCKET ==========
resource "aws_s3_bucket" "processed_data" {
  bucket = "sage-revops-processed-${data.aws_caller_identity.current.account_id}"
}

data "aws_caller_identity" "current" {}

# ========== IAM ROLE FOR LAMBDA ==========
resource "aws_iam_role" "lambda_role" {
  name = "sage-revops-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Lambda basic execution (CloudWatch logs)
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# S3 read access
resource "aws_iam_policy" "s3_read" {
  name = "sage-revops-s3-read"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        aws_s3_bucket.processed_data.arn,
        "${aws_s3_bucket.processed_data.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "s3_read" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.s3_read.arn
}

# ========== LAMBDA: get_pipeline_by_region ==========
data "archive_file" "get_pipeline_by_region_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambdas/get_pipeline_by_region/lambda_function.py"
  output_path = "${path.module}/../lambdas/get_pipeline_by_region/lambda_function.zip"
}

resource "aws_lambda_function" "get_pipeline_by_region" {
  function_name    = "sage-get-pipeline-by-region"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 256
  filename         = data.archive_file.get_pipeline_by_region_zip.output_path
  source_code_hash = data.archive_file.get_pipeline_by_region_zip.output_base64sha256
}

# ========== LAMBDA: get_pipeline_by_product ==========
data "archive_file" "get_pipeline_by_product_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambdas/get_pipeline_by_product/lambda_function.py"
  output_path = "${path.module}/../lambdas/get_pipeline_by_product/lambda_function.zip"
}

resource "aws_lambda_function" "get_pipeline_by_product" {
  function_name    = "sage-get-pipeline-by-product"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 256
  filename         = data.archive_file.get_pipeline_by_product_zip.output_path
  source_code_hash = data.archive_file.get_pipeline_by_product_zip.output_base64sha256
}

# ========== LAMBDA: get_last_month_sales ==========
data "archive_file" "get_last_month_sales_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambdas/get_last_month_sales/lambda_function.py"
  output_path = "${path.module}/../lambdas/get_last_month_sales/lambda_function.zip"
}

resource "aws_lambda_function" "get_last_month_sales" {
  function_name    = "sage-get-last-month-sales"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 256
  filename         = data.archive_file.get_last_month_sales_zip.output_path
  source_code_hash = data.archive_file.get_last_month_sales_zip.output_base64sha256

  environment {
    variables = {
      SF_USER     = var.snowflake_user
      SF_PASSWORD = var.snowflake_password
      SF_ACCOUNT  = "${var.snowflake_org}-${var.snowflake_account_name}"
    }
  }
}
