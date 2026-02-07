# RevOps Dashboard

A full-stack data analytics dashboard built to demonstrate modern cloud-native data engineering and application development. This project showcases real-time and batch data processing, REST API design, and interactive frontend development using the AWS stack.

## What This Project Does

This is an internal RevOps (Revenue Operations) analytics dashboard that:
- Displays sales pipeline data aggregated by region and product
- Shows real-time sales data queried directly from Snowflake
- Provides summary statistics and metrics
- Refreshes data on-demand with a single click
- Runs scheduled batch jobs to update cached analytics daily

The dashboard demonstrates a hybrid approach: cached data for fast loading (updated daily) and live queries for real-time insights.

## Tech Stack

**Frontend:**
- React 18 (with Vite)
- Vanilla CSS
- Modern JavaScript (ES6+)

**Backend:**
- AWS Lambda (Python 3.11)
- AWS API Gateway (REST APIs)
- AWS S3 (data storage)
- AWS EventBridge (scheduling)
- Snowflake (data warehouse)

**Infrastructure:**
- Terraform (IaC)
- Docker (for building Lambda layers)
- AWS CLI

## Project Structure
```
sage-revops-dashboard/
├── frontend/                    # React application
│   ├── src/
│   │   ├── App.jsx             # Main dashboard component
│   │   ├── App.css             # Styling
│   │   └── index.css           # Global styles
│   └── package.json
│
├── lambdas/                     # Lambda function code
│   ├── snowflake_to_s3_processor/   # Daily batch processor
│   ├── get_pipeline_by_region/      # API endpoint (cached)
│   ├── get_pipeline_by_product/     # API endpoint (cached)
│   └── get_last_month_sales/        # API endpoint (live Snowflake)
│
├── infrastructure/              # Terraform configuration
│   ├── main.tf                 # AWS provider setup
│   ├── s3.tf                   # S3 bucket for processed data
│   ├── lambdas.tf              # Lambda functions
│   ├── api_gateway.tf          # API Gateway and routes
│   ├── data_processor.tf       # Scheduled data processor
│   ├── variables.tf            # Input variables
│   └── outputs.tf              # Output values
│
├── glue-jobs/                  # AWS Glue scripts (alternative approach)
│   └── pipeline_aggregations.py
│
└── Dockerfile.layer            # For building Snowflake Lambda layer
```

## Architecture Overview

### Data Flow
```
Snowflake (FCT_SALES table)
    ↓
Lambda Data Processor (runs daily at 2 AM UTC)
    ↓
S3 (aggregated JSON files)
    ↓
API Lambda Functions (3 endpoints)
    ↓
API Gateway (REST API)
    ↓
React Frontend
```

### Backend Components

**1. Data Processor Lambda (`snowflake_to_s3_processor`)**
- **Trigger:** EventBridge schedule (daily at 2 AM UTC)
- **What it does:** Connects to Snowflake, runs aggregation queries (by region and by product), writes results to S3 as JSON
- **Why:** Pre-computes expensive aggregations for fast API responses

**2. API Lambda - By Region (`get_pipeline_by_region`)**
- **Trigger:** API Gateway GET request
- **What it does:** Reads pre-aggregated data from S3, returns JSON
- **Data source:** S3 (cached, updated daily)
- **Speed:** Very fast (~100-200ms)

**3. API Lambda - By Product (`get_pipeline_by_product`)**
- **Trigger:** API Gateway GET request
- **What it does:** Reads pre-aggregated data from S3, returns JSON
- **Data source:** S3 (cached, updated daily)
- **Speed:** Very fast (~100-200ms)

**4. API Lambda - Last Month Sales (`get_last_month_sales`)**
- **Trigger:** API Gateway GET request
- **What it does:** Queries Snowflake directly in real-time
- **Data source:** Snowflake (live query)
- **Speed:** Slower (~1-3 seconds) but always fresh

### API Endpoints
```
Base URL: https://tm4o7kgf22.execute-api.us-east-1.amazonaws.com/prod/api

GET /pipeline/by-region      → Returns pipeline aggregated by region (cached)
GET /pipeline/by-product     → Returns pipeline aggregated by product (cached)
GET /sales/last-month        → Returns last 30 days sales (live from Snowflake)
```

All endpoints return JSON with CORS enabled for browser access.

## Design Decision: Lambda vs. Glue

**Why Lambda Instead of AWS Glue?**

AWS Glue is typically used for ETL jobs like this. However, Glue jobs run in a VPC without internet access by default. To connect to Snowflake (a public endpoint), you'd need:
- VPC with NAT Gateway (~$30-40/month)
- Security groups and route tables
- VPC endpoints or internet gateway configuration

For a learning/demo project, this additional infrastructure cost and complexity wasn't justified. **Lambda provides the same functionality** (query Snowflake, transform data, write to S3) without the networking overhead.

**In a production environment**, you could absolutely use Glue for this pipeline. The `glue-jobs/` folder contains the equivalent Glue script that would work if deployed with proper VPC configuration. The choice between Lambda and Glue comes down to:
- **Lambda:** Simpler, no VPC needed, good for smaller datasets
- **Glue:** Better for large-scale ETL, built-in Spark, more powerful transformations

Both are valid approaches depending on your scale and requirements.

## Setup Instructions (A-Z)

If you're cloning this repository and want to run it yourself, here's everything you need to do:

### Prerequisites

**Tools you need installed:**
1. **AWS CLI** - [Install guide](https://aws.amazon.com/cli/)
2. **Terraform** - [Install guide](https://learn.hashicorp.com/tutorials/terraform/install-cli)
3. **Docker Desktop** - [Install guide](https://www.docker.com/products/docker-desktop/)
4. **Node.js and npm** - [Install guide](https://nodejs.org/)
5. **Git** - [Install guide](https://git-scm.com/)
6. **Python 3.11** - [Install guide](https://www.python.org/downloads/)

**Accounts you need:**
- AWS account with admin access
- Snowflake account (free trial works)

### Step 1: Clone the Repository
```bash
git clone https://github.com/YOUR_USERNAME/sage-revops-dashboard.git
cd sage-revops-dashboard
```

### Step 2: Set Up Snowflake

**2.1 Create Database and Schema:**

Log into Snowflake and run:
```sql
CREATE DATABASE SAGE_REVOPS;
CREATE SCHEMA SAGE_REVOPS.RAW;
USE SCHEMA SAGE_REVOPS.RAW;
```

**2.2 Create the Sales Table:**
```sql
CREATE TABLE FCT_SALES (
    SALE_ID NUMBER(38,0),
    PRODUCT VARCHAR(50),
    REGION VARCHAR(20),
    AMOUNT NUMBER(12,2),
    STAGE VARCHAR(30),
    CUSTOMER_NAME VARCHAR(100),
    SALE_DATE DATE,
    STATUS VARCHAR(20)
);
```

**2.3 Insert Sample Data:**
```sql
INSERT INTO FCT_SALES (SALE_ID, PRODUCT, REGION, AMOUNT, STAGE, CUSTOMER_NAME, SALE_DATE, STATUS) VALUES
(1, 'Sage Intacct', 'North', 150000, 'Negotiation', 'Acme Corp', CURRENT_DATE() - 15, 'Closed'),
(2, 'Sage Intacct', 'North', 75000, 'Proposal', 'TechStart', CURRENT_DATE() - 20, 'Open'),
(3, 'Sage Payroll', 'South', 45000, 'Qualification', 'MidCorp', CURRENT_DATE() - 10, 'Open'),
(4, 'Sage HR', 'East', 30000, 'Negotiation', 'SmallBiz', CURRENT_DATE() - 5, 'Closed'),
(5, 'Sage 50', 'West', 22000, 'Prospecting', 'Startup', CURRENT_DATE() - 8, 'Closed');

-- Add more recent data for live queries
INSERT INTO FCT_SALES (SALE_ID, PRODUCT, REGION, AMOUNT, STAGE, CUSTOMER_NAME, SALE_DATE, STATUS) VALUES
(6, 'Sage Intacct', 'North', 95000, 'Negotiation', 'BigEnterprise', CURRENT_DATE() - 3, 'Closed'),
(7, 'Sage Payroll', 'South', 42000, 'Proposal', 'RetailCo', CURRENT_DATE() - 2, 'Open'),
(8, 'Sage HR', 'West', 31000, 'Qualification', 'ServiceInc', CURRENT_DATE() - 4, 'Closed');
```

**2.4 Get Your Snowflake Connection Details:**

You'll need:
- Account URL: Found in your browser URL when logged in (e.g., `abc123.us-east-1`)
- Username: Your Snowflake username
- Password: Your Snowflake password

### Step 3: Build the Snowflake Lambda Layer

Lambda needs the Snowflake connector library. We'll build it using Docker to ensure compatibility with Lambda's Linux environment.

**3.1 Build the Layer:**
```bash
# From project root
docker build -f Dockerfile.layer -t lambda-snowflake-layer .

# Create container and extract the zip
docker create --name temp-layer lambda-snowflake-layer
docker cp temp-layer:/tmp/snowflake-layer.zip .
docker rm temp-layer
```

**3.2 Upload to AWS Lambda Layers:**
```bash
aws lambda publish-layer-version \
    --layer-name snowflake-connector \
    --description "Snowflake connector for Python 3.11" \
    --zip-file fileb://snowflake-layer.zip \
    --compatible-runtimes python3.11 \
    --region us-east-1
```

**3.3 Save the Layer ARN:**

Copy the `LayerVersionArn` from the output (you'll need it for Terraform). It looks like:
```
arn:aws:lambda:us-east-1:ACCOUNT_ID:layer:snowflake-connector:1
```

### Step 4: Configure AWS Infrastructure

**4.1 Set Up AWS CLI:**
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Default region: us-east-1
# Default output format: json
```

**4.2 Create Terraform Variables File:**
```bash
cd infrastructure
touch terraform.tfvars
```

**Edit `terraform.tfvars` and add:**
```hcl
snowflake_url       = "your-account.us-east-1"  # From Step 2.4
snowflake_user      = "YOUR_USERNAME"
snowflake_password  = "YOUR_PASSWORD"
snowflake_database  = "SAGE_REVOPS"
snowflake_schema    = "RAW"
snowflake_warehouse = "COMPUTE_WH"
aws_region          = "us-east-1"
```

**4.3 Update Lambda Layer ARN:**

Edit `infrastructure/lambdas.tf` and `infrastructure/data_processor.tf`:

Find the `layers` parameter and update with your ARN from Step 3.3:
```hcl
layers = [
    "arn:aws:lambda:us-east-1:YOUR_ACCOUNT:layer:snowflake-connector:1"
]
```

### Step 5: Deploy AWS Infrastructure

**5.1 Initialize Terraform:**
```bash
cd infrastructure
terraform init
```

**5.2 Preview Changes:**
```bash
terraform plan
```

Review the plan. It should show ~30-40 resources to be created.

**5.3 Deploy:**
```bash
terraform apply
```

Type `yes` when prompted.

**5.4 Save the API URL:**

After deployment completes, copy the `api_url` output value. You'll need it for the frontend.

### Step 6: Test the Backend

**6.1 Trigger Data Processor Manually:**
```bash
aws lambda invoke \
    --function-name sage-snowflake-data-processor \
    --payload '{}' \
    response.json
```

**6.2 Verify S3 Data:**
```bash
# Get your S3 bucket name from Terraform output
terraform output s3_bucket

# Check if data was written
aws s3 ls s3://YOUR_BUCKET_NAME/pipeline/by-region/
aws s3 ls s3://YOUR_BUCKET_NAME/pipeline/by-product/
```

**6.3 Test API Endpoints:**
```bash
# Replace with your API URL from Step 5.4
curl https://YOUR_API_URL/api/pipeline/by-region
curl https://YOUR_API_URL/api/pipeline/by-product
curl https://YOUR_API_URL/api/sales/last-month
```

All should return JSON data.

### Step 7: Set Up the React Frontend

**7.1 Install Dependencies:**
```bash
cd ../frontend
npm install
```

**7.2 Update API URL:**

Edit `frontend/src/App.jsx` and update line 5:
```javascript
const API_URL = 'https://YOUR_API_URL/api'  // Replace with your actual API URL
```

**7.3 Start Development Server:**
```bash
npm run dev
```

Open `http://localhost:5173/` in your browser.

### Step 8: Verify Everything Works

**8.1 Check the Dashboard:**

You should see:
- Pipeline by Region table (with data)
- Pipeline by Product table (with data)
- Last Month Sales 🔴 LIVE table (with data)
- Summary statistics

**8.2 Test Live Updates:**

Add a new record to Snowflake:
```sql
INSERT INTO FCT_SALES (SALE_ID, PRODUCT, REGION, AMOUNT, STAGE, CUSTOMER_NAME, SALE_DATE, STATUS) 
VALUES (99, 'Sage Intacct', 'East', 200000, 'Negotiation', 'NewClient', CURRENT_DATE(), 'Closed');
```

Click "Refresh Data" in the dashboard. The "Last Month Sales" section should update immediately with the new record.

## Maintenance and Updates

**To update cached data:**

The Lambda data processor runs automatically daily at 2 AM UTC. To trigger it manually:
```bash
aws lambda invoke \
    --function-name sage-snowflake-data-processor \
    --payload '{}' \
    response.json
```

**To modify the infrastructure:**

1. Edit the relevant Terraform files
2. Run `terraform plan` to preview changes
3. Run `terraform apply` to deploy changes

**To update Lambda function code:**

After editing Lambda code in the `lambdas/` directory:
```bash
cd infrastructure
terraform apply
```

Terraform will automatically detect code changes and redeploy the functions.

## Troubleshooting

**Problem: Lambda can't connect to Snowflake**

Solution: Check that:
- Snowflake credentials in `terraform.tfvars` are correct
- Lambda has the snowflake-connector layer attached
- Account URL format is correct (should be `account.region` not `account.snowflakecomputing.com`)

**Problem: CORS errors in browser**

Solution: Make sure API Gateway has CORS enabled for all endpoints. Check `infrastructure/api_gateway.tf`.

**Problem: "Missing Authentication Token" error**

Solution: The API route doesn't exist. Check that the route is defined in `api_gateway.tf` and deployed to the `prod` stage.

**Problem: Empty data in dashboard**

Solution: 
- Check that Snowflake has data
- Verify the data processor Lambda ran successfully
- Check CloudWatch logs for errors

## Cost Estimates

Running this project in AWS:
- **Lambda:** ~$0-1/month (within free tier for light usage)
- **API Gateway:** ~$0-1/month (within free tier for 1M requests)
- **S3:** ~$0.10/month (minimal data storage)
- **EventBridge:** Free
- **Total:** ~$0-2/month for learning/demo purposes

**Note:** Snowflake may have costs depending on your plan, but the free trial includes enough credits for this project.

## Future Enhancements

Ideas for extending this project:
- Add authentication (AWS Cognito)
- Implement data filtering and search
- Add charts and visualizations (using Recharts)
- Build a Bedrock AI insights endpoint
- Add DBT for data transformation in Snowflake
- Deploy frontend to S3 + CloudFront
- Add unit tests and CI/CD pipeline

## License

This project is for educational and demonstration purposes.

## Author

Built by Vignesh Sankar.
