import json
import boto3
import os
import base64
import datatier
from configparser import ConfigParser

def get_file_content(s3_client, bucketname, s3_key):
    try:
        response = s3_client.get_object(
            Bucket=bucketname,
            Key=s3_key
        )
        file_content = response['Body'].read()
        encoded_content = base64.b64encode(file_content).decode('utf-8')
        print(f"Successfully retrieved and encoded content for key: {s3_key}")
        return encoded_content
    except Exception as e:
        print(f"Error retrieving file content for {s3_key}: {str(e)}")
        return None

def lambda_handler(event, context):
    try:
        print("**STARTING ORGANA DOCUMENT VIEW HANDLER**")
        print("Event:", json.dumps(event))
        
        config_file = 'organa-config.ini'
        os.environ['AWS_SHARED_CREDENTIALS_FILE'] = config_file
        
        configur = ConfigParser()
        configur.read(config_file)
        
        s3_profile = 's3readwrite'
        boto3.setup_default_session(profile_name=s3_profile)
        
        bucketname = configur.get('s3', 'bucket_name')
        s3_client = boto3.client('s3')
        
        rds_endpoint = configur.get('rds', 'endpoint')
        rds_portnum = int(configur.get('rds', 'port_number'))
        rds_username = configur.get('rds', 'user_name')
        rds_pwd = configur.get('rds', 'user_pwd')
        rds_dbname = configur.get('rds', 'db_name')
        
        doc_id = event.get("pathParameters", {}).get("docid")
        if not doc_id:
            raise ValueError("Missing required parameter: docid")
        
        print(f"Received request for document ID: {doc_id}")
        
        dbConn = datatier.get_dbConn(rds_endpoint, rds_portnum, rds_username, rds_pwd, rds_dbname)
        
        sql = """
            SELECT 
                doc_id,
                original_bucket_key,
                processed_bucket_key,
                extracted_text_bucket_key,
                status,
                upload_date,
                processed_date,
                extraction_date
            FROM documents 
            WHERE doc_id = %s
        """
        row = datatier.retrieve_one_row(dbConn, sql, [doc_id])
        if not row:
            return {
                'statusCode': 404,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'GET',
                    'Access-Control-Allow-Headers': 'Content-Type'
                },
                'body': json.dumps({"error": "Document not found"})
            }
        
        document = {
            'doc_id': row[0],
            'originalBucketKey': row[1],
            'processedBucketKey': row[2],
            'extractedTextBucketKey': row[3],
            'status': row[4],
            'upload_date': row[5].isoformat() if row[5] else None,
            'processed_date': row[6].isoformat() if row[6] else None,
            'extraction_date': row[7].isoformat() if row[7] else None
        }
        
        if document['processedBucketKey']:
            document['processedData'] = get_file_content(s3_client, bucketname, document['processedBucketKey'])
        else:
            document['processedData'] = None
            print(f"No processedBucketKey for document {doc_id}")
        
        if document['originalBucketKey']:
            document['originalData'] = get_file_content(s3_client, bucketname, document['originalBucketKey'])
        else:
            document['originalData'] = None
            print(f"No originalBucketKey for document {doc_id}")
        
        if document['extractedTextBucketKey']:
            document['extractedTextData'] = get_file_content(s3_client, bucketname, document['extractedTextBucketKey'])
        else:
            document['extractedTextData'] = None
            print(f"No extractedTextBucketKey for document {doc_id}")
        
        print(f"Document {doc_id} retrieved successfully.")
        
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET',
                'Access-Control-Allow-Headers': 'Content-Type'
            },
            'body': json.dumps(document)
        }
    
    except Exception as err:
        print("**ERROR**")
        print(str(err))
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET',
                'Access-Control-Allow-Headers': 'Content-Type'
            },
            'body': json.dumps({
                'error': str(err)
            })
        }
