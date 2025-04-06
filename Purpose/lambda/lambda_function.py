import os
import json
import logging
import requests
import psycopg2
from psycopg2.extras import execute_values

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def fetch_kipu_data():
    """
    Fetch data from the Kipu API.
    Expected response: JSON with keys "admissions", "transfers", "discharges"
    """
    kipu_api_url = os.environ.get("KIPU_API_URL")
    api_key = os.environ.get("KIPU_API_KEY")
    headers = {"Authorization": f"Bearer {api_key}"}
    response = requests.get(kipu_api_url, headers=headers)
    if response.status_code != 200:
        logger.error("Error fetching data from Kipu API")
        raise Exception("Kipu API request failed")
    data = response.json()
    return data

def transform_data(raw_data):
    """
    Minimal transformation to match the Supabase schema.
    """
    admissions = raw_data.get("admissions", [])
    transfers = raw_data.get("transfers", [])
    discharges = raw_data.get("discharges", [])
    return {
        "admissions": admissions,
        "transfers": transfers,
        "discharges": discharges
    }

def load_data_to_supabase(data):
    """
    Connects to Supabase Postgres and inserts/updates records.
    Then triggers a stored procedure to refresh materialized views.
    """
    conn = psycopg2.connect(
        host=os.environ.get("SUPABASE_HOST"),
        dbname=os.environ.get("SUPABASE_DB"),
        user=os.environ.get("SUPABASE_USER"),
        password=os.environ.get("SUPABASE_PASSWORD"),
        port=os.environ.get("SUPABASE_PORT", 5432)
    )
    conn.autocommit = True
    cursor = conn.cursor()
    
    for table in ["admissions", "transfers", "discharges"]:
        records = data.get(table, [])
        if records:
            # Assumes each record is a dict whose keys match the table columns.
            columns = records[0].keys()
            sql = f"""
                INSERT INTO {table} ({', '.join(columns)}) 
                VALUES %s 
                ON CONFLICT (id) DO UPDATE SET 
                {", ".join([f"{col}=EXCLUDED.{col}" for col in columns if col != 'id'])}
            """
            values = [tuple(record[col] for col in columns) for record in records]
            try:
                execute_values(cursor, sql, values)
                logger.info(f"Inserted/Updated {len(records)} records into {table}")
            except Exception as e:
                logger.error(f"Error inserting records into {table}: {str(e)}")
                raise e

    # Trigger the stored procedure to refresh materialized views
    try:
        cursor.execute("CALL refresh_materialized_views();")
        logger.info("Materialized views refreshed")
    except Exception as e:
        logger.error("Error refreshing materialized views: " + str(e))
        raise e
    finally:
        cursor.close()
        conn.close()

def lambda_handler(event, context):
    try:
        raw_data = fetch_kipu_data()
        transformed_data = transform_data(raw_data)
        load_data_to_supabase(transformed_data)
        return {
            'statusCode': 200,
            'body': json.dumps('Data load successful')
        }
    except Exception as e:
        logger.error("ETL process failed: " + str(e))
        return {
            'statusCode': 500,
            'body': json.dumps('ETL process failed')
        }
