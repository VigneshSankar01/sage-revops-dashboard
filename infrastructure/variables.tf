variable "snowflake_org" {
  description = "Snowflake organization name"
  type        = string
}

variable "snowflake_account_name" {
  description = "Snowflake account name"
  type        = string
}

variable "snowflake_user" {
  description = "Snowflake username"
  type        = string
}

variable "snowflake_password" {
  description = "Snowflake password"
  type        = string
  sensitive   = true
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "snowflake_url" {
  description = "Snowflake account URL"
  type        = string
  default     = "your-account.snowflakecomputing.com"
}

variable "snowflake_database" {
  description = "Snowflake database"
  type        = string
  default     = "SAGE_REVOPS"
}

variable "snowflake_schema" {
  description = "Snowflake schema"
  type        = string
  default     = "RAW"
}

variable "snowflake_warehouse" {
  description = "Snowflake warehouse"
  type        = string
  default     = "COMPUTE_WH"
}
