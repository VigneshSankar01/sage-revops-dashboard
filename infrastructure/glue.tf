# IAM Role for Glue
resource "aws_iam_role" "glue_role" {
  name = "sage-glue-pipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "glue.amazonaws.com"
      }
    }]
  })
}

# Attach AWS managed policy for Glue
resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Custom policy for S3 access
resource "aws_iam_role_policy" "glue_s3_policy" {
  name = "glue-s3-access"
  role = aws_iam_role.glue_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.processed_data.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.processed_data.arn
        ]
      }
    ]
  })
}

# Upload Glue script to S3
resource "aws_s3_object" "glue_script" {
  bucket = aws_s3_bucket.processed_data.id
  key    = "scripts/pipeline_aggregations.py"
  source = "../glue-jobs/pipeline_aggregations.py"
  etag   = filemd5("../glue-jobs/pipeline_aggregations.py")
}

# Glue Job
resource "aws_glue_job" "pipeline_aggregations" {
  name     = "sage-pipeline-aggregations"
  role_arn = aws_iam_role.glue_role.arn

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.processed_data.id}/scripts/pipeline_aggregations.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--enable-metrics"                   = "true"
    "--enable-spark-ui"                  = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--TempDir"                          = "s3://${aws_s3_bucket.processed_data.id}/temp/"

    # Snowflake connection parameters
    "--snowflake_url"       = var.snowflake_url
    "--snowflake_user"      = var.snowflake_user
    "--snowflake_password"  = var.snowflake_password
    "--snowflake_database"  = var.snowflake_database
    "--snowflake_schema"    = var.snowflake_schema
    "--snowflake_warehouse" = var.snowflake_warehouse
    "--s3_output_bucket"    = aws_s3_bucket.processed_data.id

    # Snowflake connector for Spark
    "--extra-jars" = "s3://awsglue-datasets/snowflake/snowflake-jdbc-3.13.22.jar,s3://awsglue-datasets/snowflake/spark-snowflake_2.12-2.10.0-spark_3.1.jar"
  }

  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2

  execution_property {
    max_concurrent_runs = 1
  }

  tags = {
    Environment = "dev"
    Project     = "sage-revops"
  }
}
