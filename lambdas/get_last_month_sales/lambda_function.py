import json
import os
import snowflake.connector

def lambda_handler(event, context):
    try:
        params = event.get('queryStringParameters', {}) or {}
        product = params.get('product', None)

        conn = snowflake.connector.connect(
            user=os.environ['SF_USER'],
            password=os.environ['SF_PASSWORD'],
            account=os.environ['SF_ACCOUNT'],
            warehouse='COMPUTE_WH',
            database='SAGE_REVOPS',
            schema='RAW'
        )

        query = """
            SELECT 
                PRODUCT,
                REGION,
                SUM(AMOUNT) as TOTAL_AMOUNT,
                COUNT(*) as DEAL_COUNT,
                SUM(CASE WHEN STATUS = 'Closed' THEN AMOUNT ELSE 0 END) as CLOSED_AMOUNT
            FROM FCT_SALES
            WHERE SALE_DATE >= DATEADD(month, -1, CURRENT_DATE())
        """

        if product and product != 'All':
            query += f" AND PRODUCT = '{product}'"

        query += " GROUP BY PRODUCT, REGION ORDER BY TOTAL_AMOUNT DESC"

        cursor = conn.cursor()
        cursor.execute(query)
        rows = cursor.fetchall()
        columns = [desc[0].lower() for desc in cursor.description]

        data = []
        for row in rows:
            record = dict(zip(columns, row))
            for key, val in record.items():
                if hasattr(val, 'is_integer'):
                    record[key] = float(val)
            data.append(record)

        conn.close()

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'status': 'success',
                'data': data,
                'filter': product or 'All'
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