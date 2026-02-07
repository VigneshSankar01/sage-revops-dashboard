import json
import os
import boto3
import snowflake.connector
from decimal import Decimal

s3_client = boto3.client('s3')

def decimal_default(obj):
    """Helper function to convert Decimal to float for JSON serialization"""
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError

def lambda_handler(event, context):
    """
    Queries Snowflake, aggregates data, and writes to S3
    Runs on a schedule (EventBridge trigger)
    """
    
    try:
        print("Starting Snowflake data aggregation...")
        
        # Connect to Snowflake
        conn = snowflake.connector.connect(
            user=os.environ['SF_USER'],
            password=os.environ['SF_PASSWORD'],
            account=os.environ['SF_ACCOUNT'],
            warehouse='COMPUTE_WH',
            database='SAGE_REVOPS',
            schema='RAW'
        )
        
        cursor = conn.cursor()
        
        # Get S3 bucket from environment
        s3_bucket = os.environ['S3_BUCKET']
        
        # ============================================
        # Aggregation 1: Pipeline by Region
        # ============================================
        print("Aggregating by region...")
        
        region_query = """
            SELECT 
                REGION,
                SUM(AMOUNT) as TOTAL_AMOUNT,
                COUNT(*) as DEAL_COUNT,
                AVG(AMOUNT) as AVG_DEAL_SIZE,
                SUM(CASE WHEN STATUS = 'Closed' THEN AMOUNT ELSE 0 END) as CLOSED_AMOUNT,
                SUM(CASE WHEN STATUS != 'Closed' THEN AMOUNT ELSE 0 END) as OPEN_AMOUNT
            FROM FCT_SALES
            GROUP BY REGION
            ORDER BY TOTAL_AMOUNT DESC
        """
        
        cursor.execute(region_query)
        region_results = cursor.fetchall()
        columns = [desc[0].lower() for desc in cursor.description]
        
        region_data = []
        for row in region_results:
            record = dict(zip(columns, row))
            region_data.append(record)
        
        # Write to S3 with Decimal handling
        s3_client.put_object(
            Bucket=s3_bucket,
            Key='pipeline/by-region/data.json',
            Body=json.dumps(region_data, default=decimal_default),
            ContentType='application/json'
        )
        print(f"Written {len(region_data)} regions to S3")
        
        # ============================================
        # Aggregation 2: Pipeline by Product
        # ============================================
        print("Aggregating by product...")
        
        product_query = """
            SELECT 
                PRODUCT,
                SUM(AMOUNT) as TOTAL_AMOUNT,
                COUNT(*) as DEAL_COUNT,
                AVG(AMOUNT) as AVG_DEAL_SIZE
            FROM FCT_SALES
            GROUP BY PRODUCT
            ORDER BY TOTAL_AMOUNT DESC
        """
        
        cursor.execute(product_query)
        product_results = cursor.fetchall()
        columns = [desc[0].lower() for desc in cursor.description]
        
        product_data = []
        for row in product_results:
            record = dict(zip(columns, row))
            product_data.append(record)
        
        # Write to S3 with Decimal handling
        s3_client.put_object(
            Bucket=s3_bucket,
            Key='pipeline/by-product/data.json',
            Body=json.dumps(product_data, default=decimal_default),
            ContentType='application/json'
        )
        print(f"Written {len(product_data)} products to S3")
        
        # Close connection
        conn.close()
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'status': 'success',
                'message': 'Data aggregation completed',
                'regions_processed': len(region_data),
                'products_processed': len(product_data)
            })
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        import traceback
        traceback.print_exc()
        return {
            'statusCode': 500,
            'body': json.dumps({
                'status': 'error',
                'message': str(e)
            })
        }