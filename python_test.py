import snowflake.connector

try:
    conn = snowflake.connector.connect(
        user='VIGNESHSANKAR01',
        password='Vickymoneyheist@091',
        account='wlc06894.us-east-1',  # Correct format!
        warehouse='COMPUTE_WH'
    )
    print("✅ Connection successful!")
    
    # Test a simple query
    cursor = conn.cursor()
    cursor.execute("SELECT CURRENT_USER(), CURRENT_ACCOUNT(), CURRENT_REGION()")
    result = cursor.fetchone()
    print(f"Connected as: {result[0]}")
    print(f"Account: {result[1]}")
    print(f"Region: {result[2]}")
    
    conn.close()
except Exception as e:
    print(f"❌ Connection failed: {str(e)}")



