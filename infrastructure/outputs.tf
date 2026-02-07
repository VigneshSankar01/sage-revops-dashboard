output "api_url" {
  description = "API Gateway URL"
  value       = aws_api_gateway_stage.prod.invoke_url
}

output "s3_bucket" {
  description = "S3 bucket for processed data"
  value       = aws_s3_bucket.processed_data.bucket
}
