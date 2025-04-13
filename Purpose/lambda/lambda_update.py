import os
import json
import logging
import sys
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

############# Logging #################
# set up logging directory
script_dir = Path(__file__).resolve().parent
logs_dir = script_dir.parent / 'logs'

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Logging file handler
log_file = logs_dir / 'log_lambda_update.log'
fh = logging.FileHandler(log_file)
fh.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
fh.setFormatter(formatter)
logger.addHandler(fh)

# Logging stream handler
console_handler = logging.StreamHandler(sys.stdout)
console_handler.setLevel(logging.INFO)
console_handler.setFormatter(formatter)
logger.addHandler(console_handler)

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

def truncate_table(table_name):
    """
    Truncate the specified table in the Supabase database.
    Handles errors and logging
    """
    try:
        response = supabase.rpc("truncate_table_dynamic", {"p_table_name": table_name}).execute()
        response.raise_when_api_error(response.data)
    except Exception as e:
        logger.error(f"Error truncating {table_name}: {e}")
    else:
        logger.info(f"{table_name} table truncated successfully")

def load_data(records, table_name, FIRST_DATE='None', LAST_DATE=TODAY):
    """
    Load data into the specified table in the Supabase database.
    Handles errors and logging
    """
    try:
        insert_response = supabase.table(table_name).insert(records).execute()
        insert_response.raise_when_api_error(insert_response.data)
    except Exception as e:
        logger.error(f"Error inserting records into {table_name}: {e}")
        raise
    else:
        logger.info(f"{len(records)} records inserted into {table_name}: {FIRST_DATE} to {LAST_DATE}")

def update_latest_records(FIRST_DATE, LAST_DATE):
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
    truncate_table("stg_latest")
    
    # Load the new data into stg_latest using 'append' to keep the existing table schema
    records = serialize_datetimes(latest.to_dict(orient='records'))
    load_data(records, "stg_latest", FIRST_DATE, LAST_DATE)

def fetch_all_evals(params=None,endpoint="/api/patient_evaluations"):
    """
    Fetch all pages of an endpoint based on the passed parameters.

    Parameters:
        params (dict): Dictionary of parameters. Should include 'page' key.
        endpoint (str): API endpoint to fetch evaluations.

    Returns:
        pd.DataFrame: DataFrame containing all patient evaluations.
    """

    if params is None:
        params = {}

    # Set default values if not already provided.
    params.setdefault('start_date', "2024-01-01")
    params.setdefault('end_date', "2025-03-17")
    params.setdefault('evaluation_id', 856)
    params.setdefault('completed_only', True)
    params.setdefault('page', 1)

    results = []
    response = make_api_request(endpoint, params)

    # If response isn't paginated or is empty set total_pages to 1.
    total_pages = int(response.get('pagination',{}).get('total_pages', 1))
    results.extend(response[list(response.keys())[-1]]) # Extract the last key in the response, which should be the relevant data.


    if total_pages > 1:
        for page in range(2, total_pages + 1):
            params['page'] = page
            response = make_api_request("/api/patient_evaluations", params)
            results.extend(response[list(response.keys())[-1]])

    logger.info(f"Fetched {len(results)} evaluations from KIPU API: Form ID: {params['evaluation_id']}.")
    return pd.DataFrame(results)

def fetch_program_history(program_history):
    """
    Identifies and extracts the program history for all casefiles that need an update.
    Processes combinations of patient_id and patient_master_id and logs any errors encountered.
    """
    # Check if program_history is empty
    if not program_history:
        logger.warning("No program history records were found.")
        return pd.DataFrame(columns=['casefile_id', 'patient_id', 'patient_master_id', 'first_name', 'last_name', 'program_name', 'start_date', 'logged_by', 'logged_at'])
    
    # Extract patient IDs and patient master IDs from the program history.
    pids = [record['patient_id'] for record in program_history]
    pmids = [record['patient_master_id'] for record in program_history]

    # Create an empty dataframe to hold the program history data.
    program_history = pd.DataFrame()
    processed_cases = 0

    # Iterate over the provided patient IDs and patient master IDs.
    for patient_id, patient_master_id in zip(pids, pmids):
        try:
            # Build the API request parameters.
            params = {'phi_level': 'high', 'patient_master_id': patient_master_id}
            phist = make_api_request(f"/api/patients/{patient_id}/program_history", params)

            # Check if the response contains the 'patient' key.
            if 'patient' not in phist:
                logger.error(f"API response for patient {patient_id} missing 'patient' key: {phist}")
                continue

            patient_info = phist['patient']

            # Ensure 'casefile_id' exists and has the expected format.
            casefile_id = patient_info.get('casefile_id')
            if not casefile_id:
                logger.error(f"Missing casefile_id for patient {patient_id}. Response: {phist}")
                continue

            parts = casefile_id.split(':')
            if len(parts) < 2:
                logger.error(f"Invalid casefile_id format for patient {patient_id}: {casefile_id}")
                continue

            # Use the parts of the casefile_id as the patient identifiers.
            patient_id_resp = parts[0]
            patient_master_id_resp = parts[1]

            # Retrieve additional patient details.
            first_name = patient_info.get('first_name', '')
            last_name = patient_info.get('last_name', '')

            # Get the program history list.
            program_history_list = patient_info.get('program_history', [])
            if not program_history_list:
                logger.info(f"No program history found for patient {patient_id}")
                continue

            # Process each program entry.
            rows = []
            for program in program_history_list:
                # Safely get keys from the program entry.
                row = {
                    'casefile_id': casefile_id,
                    'patient_id': patient_id_resp,
                    'patient_master_id': patient_master_id_resp,
                    'first_name': first_name,
                    'last_name': last_name,
                    'program_name': program.get('program'),
                    'start_date': program.get('start_date'),
                    'logged_by': program.get('logged_by'),
                    'logged_at': program.get('logged_at')
                }
                rows.append(row)

            # If we have rows for this patient, create a dataframe and append it.
            if rows:
                phist_df = pd.DataFrame(rows)
                program_history = pd.concat([program_history, phist_df], ignore_index=True)
                processed_cases += 1
            else:
                logger.info(f"No valid program history entries for patient {patient_id}")

        except Exception as e:
            logger.error(f"Error processing patient {patient_id} (master id {patient_master_id}): {e}")
            continue

    # Convert datetime columns to the desired format.
    program_history = convert_datetime_columns(program_history, ['start_date', 'logged_at'])
    logger.info(f"{len(program_history)} program histories to update.")
    return program_history

def extract_step_down_value(eval_details):
    """
    Extracts the 'Step Down To' value from the evaluation details JSON.
    Returns "NA" if not found.
    """
    return next(
        (item.get('value') for item in eval_details['patient_evaluation']['patient_evaluation_items'] 
         if item.get('name') == 'Step Down To'),
        'NA'
    )

def update_program_history(phist_df):
    """
    Compares existing program history with new data and updates database for new records
    """
    response = supabase.table('program_history').select('*').in_('casefile_id', phist_df['casefile_id'].unique()).execute()
    existing_phist = pd.DataFrame(response.data)

    # Merge on all columns to identify which records are new
    df_merged = phist_df.merge(existing_phist, 
                            how='left', 
                            indicator=True)

    # Keep only the rows that are in the API pull but not in the existing program history table
    df_new = df_merged[df_merged['_merge'] == 'left_only'].drop(columns=['_merge', 'program_history_pk'], errors='ignore')

    # Convert the new records to a list of dictionaries
    records = serialize_datetimes(df_new.to_dict(orient='records'))

    # Insert new records into the program_history table
    load_data(records, "program_history", FIRST_DATE=phist_df['logged_at'].min(), LAST_DATE=phist_df['logged_at'].max())

def update_ama_form():
    """
    Fetches AMA forms from the KIPU API and loads to staging table
    """
    last_update_response = supabase.rpc("form_get_max_last_updated", {"p_table_name": "ama_forms"}).execute()
    last_update = last_update_response.data

    # Extract all the AMA forms (856) that were created since the last run and load to DF
    params = {'start_date': last_update, 'end_date': TODAY, 'evaluation_id': 856, 'completed_only': True, 'page': 1, 'include_stranded': False}
    ama_forms = fetch_all_evals(params)
    ama_forms = convert_datetime_columns(ama_forms, ['created_at', 'updated_at'])
    ama_forms.rename(columns={'patient_casefile_id': 'casefile_id', 'id':'form_id'}, inplace=True)
    try:
        ama_forms['patient_id'] = ama_forms['casefile_id'].str.split(':').str[0]
        ama_forms['patient_master_id'] = ama_forms['casefile_id'].str.split(':').str[1]
    except Exception as e:
        logger.error(f"Error splitting casefile_id: {e}")
        ama_forms['patient_id'] = None
        ama_forms['patient_master_id'] = None

    records = serialize_datetimes(ama_forms.to_dict(orient='records'))
    truncate_table("stg_ama_forms")
    load_data(records, "stg_ama_forms", FIRST_DATE=last_update, LAST_DATE=TODAY)

def update_admin_discharge_form():
    """
    Fetches AMA forms from the KIPU API and loads to staging table
    """
    last_update_response = supabase.rpc("form_get_max_last_updated", {"p_table_name": "admin_discharge"}).execute()
    last_update = last_update_response.data

    params = {'start_date': last_update, 'end_date': TODAY, 'evaluation_id': 1523, 'completed_only': True, 'page': 1, 'include_stranded': False}
    admin_discharge = fetch_all_evals(params)
    admin_discharge = convert_datetime_columns(admin_discharge, ['created_at', 'updated_at'])
    admin_discharge.rename(columns={'patient_casefile_id': 'casefile_id', 'id':'form_id'}, inplace=True)
    try:
        admin_discharge['patient_id'] = admin_discharge['casefile_id'].str.split(':').str[0]
        admin_discharge['patient_master_id'] = admin_discharge['casefile_id'].str.split(':').str[1]
    except Exception as e:
        logger.error(f"Error splitting casefile_id: {e}")
        admin_discharge['patient_id'] = None
        admin_discharge['patient_master_id'] = None

    records = serialize_datetimes(admin_discharge.to_dict(orient='records'))
    truncate_table("stg_admin_discharge")
    load_data(records, "stg_admin_discharge", FIRST_DATE=last_update, LAST_DATE=TODAY)

def update_detox_form():
    """
    Fetches Detox Discharge forms from the KIPU API and loads to staging table
    """
    last_update_response = supabase.rpc("form_get_max_last_updated", {"p_table_name": "detox_forms"}).execute()
    last_update = last_update_response.data

    # Pull all Detox Discharge forms (1124) that were created since the last run
    params = {'start_date': last_update, 'end_date': TODAY, 'evaluation_id': 1124, 'completed_only': True, 'page': 1}
    detox_forms = fetch_all_evals(params, endpoint="/api/patient_evaluations")
    detox_forms = convert_datetime_columns(detox_forms, ['created_at', 'updated_at'])
    detox_forms.rename(columns={'patient_casefile_id': 'casefile_id', 'id':'form_id'}, inplace=True)
    try:
        detox_forms['patient_id'] = detox_forms['casefile_id'].str.split(':').str[0]
        detox_forms['patient_master_id'] = detox_forms['casefile_id'].str.split(':').str[1]
    except Exception as e:
        logger.error(f"Error splitting casefile_id: {e}")
        detox_forms['patient_id'] = None
        detox_forms['patient_master_id'] = None

    # Extract the 'Step Down To' value from the evaluation details JSON
    for patient_eval_id in detox_forms.form_id.unique(): 
        try:
            # Make a specific API call for the evaluation details.
            eval_details = make_api_request(f"/api/patient_evaluations/{patient_eval_id}")
            
            # Extract casefile_id. Adjust the key based on your API response.
            casefile_id = eval_details['patient_evaluation'].get('patient_casefile_id')
            
            # Extract the Step Down To value.
            step_down_value = extract_step_down_value(eval_details)
            
            results = []
            # Append the relevant info to the results list.
            results.append({
                "casefile_id": casefile_id,
                "step_down_value": step_down_value
            })
        except Exception as e:
            print(f"Error processing patient_eval_id {patient_eval_id}: {e}")

    # Create a DataFrame with the stepdown value.
    detox_step_down = pd.DataFrame(results)

    # Merge stepdown values with the detox forms
    detox_final = detox_forms.merge(detox_step_down, on='casefile_id', how='left')
    detox_final['step_down_value'] = detox_final['step_down_value'].fillna('NA')
    # replace all "NA" or empty string in step down value with None
    detox_final['step_down_value'] = detox_final['step_down_value'].replace('NA', None)
    detox_final['step_down_value'] = detox_final['step_down_value'].replace('', None)
    detox_final['transferred'] = detox_final['step_down_value'].apply(lambda x: 'Yes' if x is not None else 'No')
    detox_final.drop_duplicates(inplace=True)

    # Convert final table to list of dictionaries
    records = serialize_datetimes(detox_final.to_dict(orient='records'))

    truncate_table("stg_detox_forms")
    load_data(records, "stg_detox_forms", FIRST_DATE=last_update, LAST_DATE=TODAY)

    pass

def lambda_handler(event, context):
    try:
        main()
        return {
            "statusCode": 200,
            "body": json.dumps("Lambda execution finished successfully")
        }
    except Exception as e:
        logger.error("Error occurred: " + str(e))
        return {
            "statusCode": 500,
            "body": json.dumps("Error occurred during execution")
        }

############# MAIN EXECUTION #################
def main():
    # Update stg_latest table with the latest records
    last_update_response = supabase.rpc("get_max_last_updated").execute()
    last_update = last_update_response.data
    update_latest_records(last_update, TODAY)

    # Update program history with the latest records
    phist_response = supabase.rpc("fetch_diff_records").execute()
    program_history = phist_response.data
    phist_df = fetch_program_history(program_history)
    if phist_df.empty:
        logger.warning("No program history records to update.")
    else:
        update_program_history(phist_df)

    # Execute stored proc to upsert latest data into the main table
    before_count_response = supabase.table('latest').select('*', count='exact').execute()
    before_count = before_count_response.count
    try:
        response = supabase.rpc("call_proc", {"p_proc_name": "upsert_latest_data"}).execute()
        response.raise_when_api_error(response.data)
    except Exception as e:
        logger.error(f"Error executing upsert_latest_data: {e}")
        raise
    after_count_response = supabase.table('latest').select('*', count='exact').execute()
    after_count = after_count_response.count
    logger.info(f"LATEST TABLE UPDATED FROM {before_count} TO {after_count} RECORDS.")

    # Update forms
    update_ama_form()
    before_count_response = supabase.table('ama_forms').select('*', count='exact').execute()
    before_count = before_count_response.count
    supabase.rpc("call_proc", {"p_proc_name": "upsert_ama_forms_data"}).execute()
    after_count_response = supabase.table('ama_forms').select('*', count='exact').execute()
    after_count = after_count_response.count
    logger.info(f"AMA FORMS UPDATED FROM. {before_count} TO {after_count} RECORDS.")

    update_detox_form()
    before_count_response = supabase.table('detox_forms').select('*', count='exact').execute()
    before_count = before_count_response.count
    supabase.rpc("call_proc", {"p_proc_name": "upsert_detox_discharge_forms_data"}).execute()
    after_count_response = supabase.table('detox_forms').select('*', count='exact').execute()
    after_count = after_count_response.count
    logger.info(f"DETOX FORMS UPDATED FROM. {before_count} TO {after_count} RECORDS.")

    update_admin_discharge_form()
    before_count_response = supabase.table('admin_discharge').select('*', count='exact').execute()
    before_count = before_count_response.count
    supabase.rpc("call_proc", {"p_proc_name": "upsert_admin_discharge_data"}).execute()
    after_count_response = supabase.table('admin_discharge').select('*', count='exact').execute()
    after_count = after_count_response.count
    logger.info(f"ADMIN FORMS UPDATED FROM. {before_count} TO {after_count} RECORDS.")

    # Update materialized views
    views = ['vw_program_history','vw_daily_census','vw_discharges']

    for view in views:
        try:
            before_count_response = supabase.table(view).select('*', count='exact').execute()
            before_count = before_count_response.count
            response = supabase.rpc("refresh_materialized_view", {"view_name": view}).execute()
            after_count_response = supabase.table(view).select('*', count='exact').execute()
            after_count = after_count_response.count
            response.raise_when_api_error(response.data)
            logger.info(f"{view} UPDATED FROM. {before_count} TO {after_count} RECORDS.")
        except Exception as e:
            logger.error(f"Error refreshing materialized view {view}: {e}")

if __name__ == "__main__":
    main()


 