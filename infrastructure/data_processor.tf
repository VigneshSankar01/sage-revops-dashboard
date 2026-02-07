# ============================================
# Lambda Function for Snowflake Data Processing
# ============================================

# Lambda IAM Role
resource "aws_iam_role" "data_processor_role" {
  name = "sage-data-processor-role"

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

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "data_processor_basic" {
  role       = aws_iam_role.data_processor_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom policy for S3 write access
resource "aws_iam_role_policy" "data_processor_s3" {
  name = "s3-write-access"
  role = aws_iam_role.data_processor_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:GetObject"
      ]
      Resource = "${aws_s3_bucket.processed_data.arn}/*"
    }]
  })
}

# Package the Lambda function
data "archive_file" "data_processor_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/snowflake_to_s3_processor"
  output_path = "${path.module}/data_processor.zip"
}

# Lambda Function
resource "aws_lambda_function" "data_processor" {
  filename         = data.archive_file.data_processor_zip.output_path
  function_name    = "sage-snowflake-data-processor"
  role             = aws_iam_role.data_processor_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  timeout          = 300 # 5 minutes
  memory_size      = 512
  source_code_hash = data.archive_file.data_processor_zip.output_base64sha256

  environment {
    variables = {
      SF_USER     = var.snowflake_user
      SF_PASSWORD = var.snowflake_password
      SF_ACCOUNT  = var.snowflake_url
      S3_BUCKET   = aws_s3_bucket.processed_data.id
    }
  }

  # Use your Layer ARN here!
  layers = [
    "arn:aws:lambda:us-east-1:022499024283:layer:snowflake-connector:3"
  ]
}

# ============================================
# EventBridge Schedule (Daily at 2 AM UTC)
# ============================================

resource "aws_cloudwatch_event_rule" "daily_data_processing" {
  name                = "sage-daily-data-processing"
  description         = "Trigger data processor Lambda daily"
  schedule_expression = "cron(0 2 * * ? *)"
}

resource "aws_cloudwatch_event_target" "data_processor_target" {
  rule      = aws_cloudwatch_event_rule.daily_data_processing.name
  target_id = "DataProcessorTarget"
  arn       = aws_lambda_function.data_processor.arn
}

# Permission for EventBridge to invoke Lambda
resource "aws_lambda_permission" "allow_eventbridge_data_processor" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_data_processing.arn
}

# Output the Lambda function name
output "data_processor_function_name" {
  value       = aws_lambda_function.data_processor.function_name
  description = "Name of the data processor Lambda function"
}
