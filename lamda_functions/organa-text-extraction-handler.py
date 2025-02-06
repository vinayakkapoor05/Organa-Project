import json
import os
import time
import uuid
import boto3
from configparser import ConfigParser
import datatier 
import pathlib
import re

UUID_REGEX = re.compile(
    r'[0-9a-fA-F]{8}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}'
)

def extract_doc_id(key):
    basename_with_uuid = pathlib.Path(key).stem
    match = UUID_REGEX.search(basename_with_uuid)
    if match:
        return match.group()
    else:
        return None

def lambda_handler(event, context):
    try:
        print("**STARTING ORGANA CONTENT EXTRACTION**")
        print("Event:", json.dumps(event))
        
        config_file = 'organa-config.ini'
        os.environ['AWS_SHARED_CREDENTIALS_FILE'] = config_file
        
        configur = ConfigParser()
        configur.read(config_file)
        
        s3_profile = 's3readwrite'
        boto3.setup_default_session(profile_name=s3_profile)
        
        bucketname = configur.get('s3', 'bucket_name')
        
        rds_endpoint = configur.get('rds', 'endpoint')
        rds_portnum = int(configur.get('rds', 'port_number'))
        rds_username = configur.get('rds', 'user_name')
        rds_pwd = configur.get('rds', 'user_pwd')
        rds_dbname = configur.get('rds', 'db_name')
        
        s3_client = boto3.client('s3')
        textract_client = boto3.client('textract')
        
        dbConn = datatier.get_dbConn(rds_endpoint, rds_portnum, rds_username, rds_pwd, rds_dbname)
        
        for record in event['Records']:
            bucket = record['s3']['bucket']['name']
            key = record['s3']['object']['key']
            
            if not key.startswith('organa-processed/'):
                print(f"Skipping file not in organa-processed/: {key}")
                continue
            
            if not key.lower().endswith('.pdf'):
                print(f"Skipping non-PDF file: {key}")
                continue
            
            print(f"Starting Textract analysis for: {key}")
            
            try:
                doc_id = extract_doc_id(key)
                if not doc_id:
                    raise ValueError("UUID not found in the key.")
                print(f"Extracted doc_id: {doc_id}")
            except ValueError as ve:
                print(f"Invalid key format, cannot extract doc_id: {key}. Error: {str(ve)}")
                sql_update_status_fail = """
                UPDATE documents 
                SET status = %s 
                WHERE processed_bucket_key = %s;
                """
                try:
                    datatier.perform_action(dbConn, sql_update_status_fail, ['failed', key])
                    print(f"Updated status to 'failed' for key: {key}")
                except Exception as update_err:
                    print(f"Error updating status to 'failed' for key {key}: {str(update_err)}")
                continue
            
            sql_check = "SELECT COUNT(*) FROM documents WHERE doc_id = %s;"
            count = datatier.retrieve_one_row(dbConn, sql_check, [doc_id])
            print(f"Number of records with doc_id {doc_id}: {count[0]}")
            if count[0] == 0:
                print(f"No records found with doc_id: {doc_id}")
                sql_update_status_fail = """
                UPDATE documents 
                SET status = %s 
                WHERE processed_bucket_key = %s;
                """
                try:
                    datatier.perform_action(dbConn, sql_update_status_fail, ['failed', key])
                    print(f"Updated status to 'failed' for key: {key}")
                except Exception as update_err:
                    print(f"Error updating status to 'failed' for key {key}: {str(update_err)}")
                continue
            
            sql_update_status = """
            UPDATE documents 
            SET status = %s, extraction_date = NOW() 
            WHERE doc_id = %s;
            """
            try:
                affected_rows = datatier.perform_action(dbConn, sql_update_status, ['extracting', doc_id])
                print(f"Rows affected by status update to 'extracting': {affected_rows}")
                if affected_rows == 0:
                    print(f"No rows updated for doc_id: {doc_id}")
            except Exception as e:
                print(f"Exception during status update to 'extracting' for doc_id {doc_id}: {str(e)}")
                continue 
            try:
                response = textract_client.start_document_analysis(
                    DocumentLocation={
                        'S3Object': {
                            'Bucket': bucket,
                            'Name': key
                        }
                    },
                    FeatureTypes=["TABLES", "FORMS"]
                )
                job_id = response['JobId']
                print(f"Textract JobId: {job_id}")
            except Exception as textract_err:
                print(f"Error starting Textract job for {key}: {str(textract_err)}")
                try:
                    datatier.perform_action(dbConn, sql_update_status, ['failed', doc_id])
                    print(f"Updated status to 'failed' for doc_id: {doc_id}")
                except Exception as update_err:
                    print(f"Error updating status to 'failed' for doc_id {doc_id}: {str(update_err)}")
                continue
            
            try:
                while True:
                    job_status = textract_client.get_document_analysis(JobId=job_id)
                    status = job_status['JobStatus']
                    
                    if status in ['SUCCEEDED', 'FAILED']:
                        break
                    print(f"Textract job {job_id} status: {status}. Waiting...")
                    time.sleep(2)  
            except Exception as poll_err:
                print(f"Error polling Textract job {job_id}: {str(poll_err)}")
                try:
                    datatier.perform_action(dbConn, sql_update_status, ['failed', doc_id])
                    print(f"Updated status to 'failed' for doc_id: {doc_id}")
                except Exception as update_err:
                    print(f"Error updating status to 'failed' for doc_id {doc_id}: {str(update_err)}")
                continue
            
            if status == 'FAILED':
                print(f"Textract job {job_id} failed for file {key}.")
                try:
                    datatier.perform_action(dbConn, sql_update_status, ['failed', doc_id])
                    print(f"Updated status to 'failed' for doc_id: {doc_id}")
                except Exception as update_err:
                    print(f"Error updating status to 'failed' for doc_id {doc_id}: {str(update_err)}")
                continue
            
            print(f"Textract job {job_id} succeeded, extracting text lines...")
            
            pages = []
            while True:
                pages.append(job_status)
                if 'NextToken' in job_status:
                    job_status = textract_client.get_document_analysis(JobId=job_id, NextToken=job_status['NextToken'])
                else:
                    break
            
            all_text = []
            for page_data in pages:
                for block in page_data['Blocks']:
                    if block['BlockType'] == 'LINE' and 'Text' in block:
                        all_text.append(block['Text'])
            
            extracted_text = "\n".join(all_text)
            print(f"Extracted text length: {len(extracted_text)}")
            extracted_text_key = key.replace('organa-processed/', 'organa-extracted-text/').replace('.pdf', '.txt')
            print(f"Extracted Text S3 Key: {extracted_text_key}")
            
            try:
                s3_client.put_object(
                    Bucket=bucket,
                    Key=extracted_text_key,
                    Body=extracted_text.encode('utf-8'),
                    ContentType='text/plain'
                )
                print(f"Uploaded extracted text to {extracted_text_key}")
            except Exception as upload_err:
                print(f"Error uploading extracted text {extracted_text_key}: {str(upload_err)}")
                try:
                    datatier.perform_action(dbConn, sql_update_status, ['failed', doc_id])
                    print(f"Updated status to 'failed' for doc_id: {doc_id}")
                except Exception as update_err:
                    print(f"Error updating status to 'failed' for doc_id {doc_id}: {str(update_err)}")
                continue
            
            sql_update_extracted = """
            UPDATE documents 
            SET extracted_text_bucket_key = %s, status = %s 
            WHERE doc_id = %s;
            """
            try:
                affected_rows = datatier.perform_action(dbConn, sql_update_extracted, [extracted_text_key, 'extracted', doc_id])
                print(f"Rows affected by extracted text update: {affected_rows}")
                if affected_rows == 0:
                    print(f"No rows updated for doc_id: {doc_id}")
            except Exception as e:
                print(f"Exception during extracted text update for doc_id {doc_id}: {str(e)}")
                try:
                    datatier.perform_action(dbConn, sql_update_status, ['failed', doc_id])
                    print(f"Updated status to 'failed' for doc_id: {doc_id}")
                except Exception as update_err:
                    print(f"Error updating status to 'failed' for doc_id {doc_id}: {str(update_err)}")
                continue
            
            print(f"Text extraction complete and stored at {extracted_text_key}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'PDF processing complete'})
        }
        
    except Exception as err:
        print("**ERROR**")
        print(str(err))
        return {
            'statusCode': 500,
            'body': json.dumps({"error": str(err)})
        }
