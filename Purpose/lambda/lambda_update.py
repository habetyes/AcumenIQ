import os
import json
import logging
import requests
from supabase import create_client, Client
from dotenv import load_dotenv
from pathlib import Path
import datetime
import pandas as pd
import pytz
import hmac
import hashlib
import base64
import math

# Load environment variables from .env file
env_path = Path(__file__).parent.resolve().parent / '.env'
if env_path.exists():
    load_dotenv(dotenv_path=env_path)
else:
    print('No .env file found.')
print(env_path)

# set up logging directory
script_dir = Path(__file__).resolve().parent
logs_dir = script_dir.parent / 'logs'

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)
log_file = logs_dir / 'log_lambda_update.log'
fh = logging.FileHandler(log_file)
fh.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
fh.setFormatter(formatter)
logger.addHandler(fh)

# Suppress HTTPX logging
logging.getLogger("httpx").setLevel(logging.ERROR)



############# Environment Variables #################
# Supabase
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# Kipu
KIPU_ACCESS_ID = os.environ.get("ACCESS_ID")
KIPU_SECRET_KEY = os.environ.get("SECRET_KEY")
KIPU_APP_ID = os.environ.get("APP_ID")
KIPU_BASE_URL = os.environ.get("BASE_URL")

ARIZONA_TZ = pytz.timezone('America/Phoenix')
TODAY = datetime.datetime.today().strftime('%Y-%m-%d')

############# Function Definitions #################
def serialize_datetimes(obj):
    """
    Recursively serialize datetime objects to ISO format.
    Handles NaN values by converting them to None.
    """
    if isinstance(obj, float) and math.isnan(obj):
        return None
    if isinstance(obj, datetime.datetime):
        return obj.isoformat()
    elif isinstance(obj, datetime.date):
        return obj.isoformat()  # This handles date objects
    elif isinstance(obj, dict):
        return {k: serialize_datetimes(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [serialize_datetimes(item) for item in obj]
    else:
        return obj

# KIPU Connection Functions
def generate_signature(endpoint, query_params=None):
    """Generate the HMAC SHA1 signature for the given endpoint and query parameters."""
    date = datetime.datetime.now(datetime.UTC).strftime("%a, %d %b %Y %H:%M:%S GMT")
    request_uri = f"{endpoint}?app_id={KIPU_APP_ID}"
    if query_params:
        request_uri += "&" + "&".join([f"{k}={v}" for k, v in query_params.items()])
    canonical_string = f",,{request_uri},{date}"
    key_bytes = KIPU_SECRET_KEY.encode("utf-8")
    hmac_sha1 = hmac.new(key_bytes, canonical_string.encode("utf-8"), hashlib.sha1)
    signature = base64.b64encode(hmac_sha1.digest()).decode("utf-8")
    return signature, date, request_uri

def make_api_request(endpoint, query_params=None):
    """Make a GET request to the specified endpoint with optional query parameters."""
    signature, date, request_uri = generate_signature(endpoint, query_params)
    authorization = f"APIAuth {KIPU_ACCESS_ID}:{signature}"
    headers = {
        "Accept": "application/vnd.kipusystems+json; version=3",
        "Date": date,
        "Authorization": authorization
    }
    url = f"{KIPU_BASE_URL}{request_uri}"
    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        data = response.json()
        return data
    except requests.exceptions.HTTPError as err:
        print(f"HTTP error: {err}")
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.content.decode()}")

def fetch_latest_records(FIRST_DATE, LAST_DATE, engine=supabase):
    """
    Fetches records from Latest endpoint for those updated between FIRST_DATE and LAST_DATE
    Truncates stg_latest table
    Loads records into the stg_latest table.
    """
    # Build API request parameters and fetch dat
    params = {'start_date': f"{FIRST_DATE}", 'end_date': f"{LAST_DATE}"}
    patients = make_api_request("/api/patients/latest", params)  # Fetch patients with query param

    # Normalize the JSON and perform data transformations
    latest = pd.json_normalize(patients['patients'])
    latest['insurance_company'] = latest['insurances'].apply(lambda x: x[0].get('insurance_company') if isinstance(x, list) and len(x) > 0 else None)
    latest['patient_id'] = latest['casefile_id'].str.split(':').str[0]
    latest['patient_master_id'] = latest['casefile_id'].str.split(':').str[1]
    latest = latest[['casefile_id', 'patient_id', 'patient_master_id', 'first_name', 'last_name', 'gender', 'first_contact_date','admission_date',
        'discharge_date', 'anticipated_discharge_date', 'discharge_type',
        'discharge_type_code', 'referrer_name', 'mr_number', 'payment_method',
        'payment_method_category', 'created_at', 'last_updated_at',
        'insurance_company', 'level_of_care', 'program', 'location_id',
        'location_name', 'record_source']]
    latest = convert_datetime_columns(latest, ['created_at', 'last_updated_at', 'admission_date', 'discharge_date', 'anticipated_discharge_date', 'first_contact_date'])

    # Truncate the stg_latest table before inserting new data.
    try:
        trunc_response = supabase.rpc("truncate_table_dynamic", {"p_table_name": "stg_latest"}).execute()
        trunc_response.raise_when_api_error(trunc_response.data)
    except Exception as e:
        logger.error(f"Error truncating stg_latest: {e}")
    else:
        logger.info("stg_latest table truncated successfully")
    
    # Load the new data into stg_latest using 'append' to keep the existing table schema
    records = serialize_datetimes(latest.to_dict(orient='records'))
    try:
        insert_response = supabase.table("stg_latest").insert(records).execute()
        insert_response.raise_when_api_error(insert_response.data)
    except Exception as e:
        logger.error(f"Error inserting records into stg_latest: {e}")
        raise
    else:
        logger.info(f"Inserted {len(records)} records into stg_latest: {FIRST_DATE} to {LAST_DATE}")


############# HELPER FUNCTIONS #################
def convert_datetime_columns(df, columns, tz='America/Phoenix', date_format='%Y-%m-%d %H:%M:%S'):
    """
    Convert specified columns in a DataFrame from a UTC (Zulu) string timestamp 
    to the desired time zone and format as a string, only if they appear to be in UTC.

    Parameters:
      df (pd.DataFrame): The DataFrame containing the columns.
      columns (list): List of column names to convert.
      tz (str or tzinfo): The target time zone. Default is 'America/Phoenix'.
      date_format (str): The desired datetime format. Default is '%Y-%m-%d %H:%M:%S'.
      
    Returns:
      pd.DataFrame: DataFrame with converted datetime columns.
    """
    # Ensure the target time zone is a pytz timezone object
    if isinstance(tz, str):
        target_tz = pytz.timezone(tz)
    else:
        target_tz = tz

    for col in columns:
        if df[col].dropna().empty:
            continue  # Skip empty columns
        sample = df[col].dropna().iloc[0]

        # If the sample is a string that ends with 'Z' or contains '+00:00', assume it's UTC.
        if isinstance(sample, str) and (sample.endswith('Z') or '+00:00' in sample):
            df[col] = pd.to_datetime(df[col], utc=True, errors='coerce') \
                        .dt.tz_convert(target_tz) \
                        .dt.strftime(date_format)
        else:
            # Otherwise, assume the timestamp is already in the target time zone,
            # so just reformat it.
            df[col] = pd.to_datetime(df[col], errors='coerce').dt.strftime(date_format)

    return df



############# MAIN EXECUTION #################
response = supabase.rpc("get_max_last_updated").execute()
last_update = response.data
print(last_update)
fetch_latest_records(last_update, TODAY)

# EVERYTHING BELOW THIS LINE IS BOILERPLATE THAT CAN BE REMOVED
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
