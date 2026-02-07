import boto3
import json

s3 = boto3.client('s3')
BUCKET = 'sage-revops-processed'

def lambda_handler(event, context):
    try:
        response = s3.get_object(
            Bucket=BUCKET,
            Key='pipeline/by-region/data.json'
        )

        raw = response['Body'].read().decode('utf-8')
        data = json.loads(raw)

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'status': 'success',
                'data': data
            })
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'status': 'error',
                'message': str(e)
            })
        }