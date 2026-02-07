# ========== API GATEWAY ==========
resource "aws_api_gateway_rest_api" "sage_api" {
  name        = "sage-revops-api"
  description = "Sage RevOps Dashboard API"
}

# /api
resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.sage_api.id
  parent_id   = aws_api_gateway_rest_api.sage_api.root_resource_id
  path_part   = "api"
}

# /api/pipeline
resource "aws_api_gateway_resource" "pipeline" {
  rest_api_id = aws_api_gateway_rest_api.sage_api.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "pipeline"
}

# /api/pipeline/by-region
resource "aws_api_gateway_resource" "by_region" {
  rest_api_id = aws_api_gateway_rest_api.sage_api.id
  parent_id   = aws_api_gateway_resource.pipeline.id
  path_part   = "by-region"
}

# /api/pipeline/by-product
resource "aws_api_gateway_resource" "by_product" {
  rest_api_id = aws_api_gateway_rest_api.sage_api.id
  parent_id   = aws_api_gateway_resource.pipeline.id
  path_part   = "by-product"
}

# /api/sales
resource "aws_api_gateway_resource" "sales" {
  rest_api_id = aws_api_gateway_rest_api.sage_api.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "sales"
}

# /api/sales/last-month
resource "aws_api_gateway_resource" "last_month" {
  rest_api_id = aws_api_gateway_rest_api.sage_api.id
  parent_id   = aws_api_gateway_resource.sales.id
  path_part   = "last-month"
}

# ========== GET /api/pipeline/by-region ==========
resource "aws_api_gateway_method" "get_by_region" {
  rest_api_id   = aws_api_gateway_rest_api.sage_api.id
  resource_id   = aws_api_gateway_resource.by_region.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_by_region_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.sage_api.id
  resource_id             = aws_api_gateway_resource.by_region.id
  http_method             = aws_api_gateway_method.get_by_region.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.get_pipeline_by_region.invoke_arn
}

resource "aws_lambda_permission" "api_gw_by_region" {
  statement_id  = "AllowAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_pipeline_by_region.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.sage_api.execution_arn}/*/*"
}

# ========== GET /api/pipeline/by-product ==========
resource "aws_api_gateway_method" "get_by_product" {
  rest_api_id   = aws_api_gateway_rest_api.sage_api.id
  resource_id   = aws_api_gateway_resource.by_product.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_by_product_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.sage_api.id
  resource_id             = aws_api_gateway_resource.by_product.id
  http_method             = aws_api_gateway_method.get_by_product.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.get_pipeline_by_product.invoke_arn
}

resource "aws_lambda_permission" "api_gw_by_product" {
  statement_id  = "AllowAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_pipeline_by_product.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.sage_api.execution_arn}/*/*"
}

# ========== GET /api/sales/last-month ==========
resource "aws_api_gateway_method" "get_last_month" {
  rest_api_id   = aws_api_gateway_rest_api.sage_api.id
  resource_id   = aws_api_gateway_resource.last_month.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_last_month_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.sage_api.id
  resource_id             = aws_api_gateway_resource.last_month.id
  http_method             = aws_api_gateway_method.get_last_month.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.get_last_month_sales.invoke_arn
}

resource "aws_lambda_permission" "api_gw_last_month" {
  statement_id  = "AllowAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_last_month_sales.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.sage_api.execution_arn}/*/*"
}

# ========== CORS (OPTIONS methods) ==========
module "cors_by_region" {
  source      = "./modules/cors"
  rest_api_id = aws_api_gateway_rest_api.sage_api.id
  resource_id = aws_api_gateway_resource.by_region.id
}

module "cors_by_product" {
  source      = "./modules/cors"
  rest_api_id = aws_api_gateway_rest_api.sage_api.id
  resource_id = aws_api_gateway_resource.by_product.id
}

module "cors_last_month" {
  source      = "./modules/cors"
  rest_api_id = aws_api_gateway_rest_api.sage_api.id
  resource_id = aws_api_gateway_resource.last_month.id
}

# ========== DEPLOY ==========
resource "aws_api_gateway_deployment" "sage_deployment" {
  rest_api_id = aws_api_gateway_rest_api.sage_api.id

  depends_on = [
    aws_api_gateway_integration.get_by_region_lambda,
    aws_api_gateway_integration.get_by_product_lambda,
    aws_api_gateway_integration.get_last_month_lambda,
    module.cors_by_region,
    module.cors_by_product,
    module.cors_last_month
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.sage_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.sage_api.id
  stage_name    = "prod"
}
