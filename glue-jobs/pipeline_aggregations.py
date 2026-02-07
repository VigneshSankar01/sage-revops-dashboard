import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql import functions as F
import boto3
import json

# Get job parameters
args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    'snowflake_url',
    'snowflake_user',
    'snowflake_password',
    'snowflake_database',
    'snowflake_schema',
    'snowflake_warehouse',
    's3_output_bucket'
])

# Initialize Glue context
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Snowflake connection options
snowflake_options = {
    "sfURL": args['snowflake_url'],
    "sfUser": args['snowflake_user'],
    "sfPassword": args['snowflake_password'],
    "sfDatabase": args['snowflake_database'],
    "sfSchema": args['snowflake_schema'],
    "sfWarehouse": args['snowflake_warehouse']
}

print("Starting Glue job: Reading from Snowflake...")

# Read the raw sales data from Snowflake
df = spark.read \
    .format("snowflake") \
    .options(**snowflake_options) \
    .option("dbtable", "FCT_SALES") \
    .load()

print(f"Total rows read from Snowflake: {df.count()}")

# Aggregation 1: Pipeline by Region
by_region = df.groupBy("REGION").agg(
    F.sum("AMOUNT").alias("total_amount"),
    F.count("*").alias("deal_count"),
    F.avg("AMOUNT").alias("avg_deal_size"),
    F.sum(F.when(F.col("STATUS") == "Closed", F.col("AMOUNT")).otherwise(0)).alias("closed_amount"),
    F.sum(F.when(F.col("STATUS") != "Closed", F.col("AMOUNT")).otherwise(0)).alias("open_amount")
).orderBy(F.desc("total_amount"))

# Aggregation 2: Pipeline by Product
by_product = df.groupBy("PRODUCT").agg(
    F.sum("AMOUNT").alias("total_amount"),
    F.count("*").alias("deal_count"),
    F.avg("AMOUNT").alias("avg_deal_size")
).orderBy(F.desc("total_amount"))

# Convert to JSON and write to S3
s3_bucket = args['s3_output_bucket']
s3 = boto3.client('s3')

# Write by-region
region_json = by_region.toPandas().to_json(orient='records')
s3.put_object(
    Bucket=s3_bucket,
    Key='pipeline/by-region/data.json',
    Body=region_json,
    ContentType='application/json'
)
print(f"Written by-region data to s3://{s3_bucket}/pipeline/by-region/data.json")

# Write by-product
product_json = by_product.toPandas().to_json(orient='records')
s3.put_object(
    Bucket=s3_bucket,
    Key='pipeline/by-product/data.json',
    Body=product_json,
    ContentType='application/json'
)
print(f"Written by-product data to s3://{s3_bucket}/pipeline/by-product/data.json")

job.commit()
print("Glue job completed successfully!")