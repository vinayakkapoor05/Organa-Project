import json
import os
from typing import List, Optional, Dict
import boto3
import openai
import psycopg
from psycopg.rows import dict_row
import datatier 
from configparser import ConfigParser
import re
import pathlib

UUID_REGEX = re.compile(
    r'[0-9a-fA-F]{8}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}'
)

def create_embedding(text: str) -> List[float]:
    response = openai.Embedding.create(
        input=text,
        model="text-embedding-ada-002"  
    )
    return response['data'][0]['embedding']

def get_original_path(extracted_path: str) -> str:
    return extracted_path.replace('organa-extracted-text/', 'organa-original/').replace('.txt', '.pdf')

def extract_doc_id(key: str) -> Optional[str]:
    basename_with_uuid = pathlib.Path(key).stem
    match = UUID_REGEX.search(basename_with_uuid)
    if match:
        return match.group()
    else:
        return None

def get_document_metadata(conn, original_path: str) -> Optional[Dict]:
    sql = """
    SELECT userid, processed_bucket_key, doc_id
    FROM documents 
    WHERE original_bucket_key = %s
    """
    result = datatier.retrieve_one_row(conn, sql, [original_path])
    if result is None:
        return None
    return {
        'userid': result[0],
        'processed_bucket_key': result[1],
        'doc_id': result[2]
    }

def store_embedding(conn, user_id: str, doc_id: str, processed_bucket_key: str, extracted_path: str, embedding: List[float]):
    sql = """
    INSERT INTO document_embeddings 
    (doc_id, user_id, processeddatafile, extractedtextpath, embedding)
    VALUES (%s, %s, %s, %s, %s)
    """
    try:
        with conn.cursor() as cur:
            cur.execute(sql, (doc_id, user_id, processed_bucket_key, extracted_path, embedding))
            print(f"Executed INSERT for doc_id: {doc_id}, user_id: {user_id}, file: {extracted_path}")
        conn.commit()
        print(f"Successfully committed transaction for {extracted_path}")
    except Exception as e:
        conn.rollback()
        print(f"Error in store_embedding: {str(e)}")
        raise

def process_document(s3_client, mysql_conn, pg_conn, bucket: str, key: str):
    try:
        response = s3_client.get_object(Bucket=bucket, Key=key)
        extracted_text = response['Body'].read().decode('utf-8')
        print(f"Retrieved text from S3: {key} (length: {len(extracted_text)})")
        
        embedding = create_embedding(extracted_text)
        print(f"Generated embedding (length: {len(embedding)})")
        
        original_path = get_original_path(key)
        metadata = get_document_metadata(mysql_conn, original_path)
        if not metadata:
            print(f"No matching document record found for {original_path}")
            return
        print(f"Retrieved metadata for user_id: {metadata['userid']}, doc_id: {metadata['doc_id']}")
            
        store_embedding(pg_conn, metadata['userid'], metadata['doc_id'], metadata['processed_bucket_key'], key, embedding)
        print(f"Successfully processed {key}")
        
    except Exception as e:
        print(f"Error processing {key}: {str(e)}")
        raise   

def setup_connections(config: ConfigParser):
    s3_client = boto3.client(
        's3',
        region_name=config.get('s3readwrite', 'region_name'),
        aws_access_key_id=config.get('s3readwrite', 'aws_access_key_id'),
        aws_secret_access_key=config.get('s3readwrite', 'aws_secret_access_key')
    )
    
    mysql_conn = datatier.get_dbConn(
        config.get('mysql', 'endpoint'),
        int(config.get('mysql', 'port_number')),
        config.get('mysql', 'user_name'),
        config.get('mysql', 'user_pwd'),
        config.get('mysql', 'db_name')
    )
    
    pg_conn = psycopg.connect(
        f"host={config.get('postgres', 'endpoint')} "
        f"port={config.get('postgres', 'port_number')} "
        f"dbname={config.get('postgres', 'db_name')} "
        f"user={config.get('postgres', 'user_name')} "
        f"password={config.get('postgres', 'user_pwd')}",
        row_factory=dict_row,
        autocommit=True   
    )
    
    return s3_client, mysql_conn, pg_conn

def lambda_handler(event, context):
    print("Starting embedding generation")
    
    try:
        config = ConfigParser()
        config.read('organa-config.ini')
        
        openai.api_key = config.get('openai', 'api_key')
        
        s3_client, mysql_conn, pg_conn = setup_connections(config)
        
        try:
            for record in event['Records']:
                bucket = record['s3']['bucket']['name']
                key = record['s3']['object']['key']
                print(f"Processing file from bucket: {bucket}, key: {key}")
                process_document(s3_client, mysql_conn, pg_conn, bucket, key)
                
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'Processing complete'})
            }
            
        finally:
            mysql_conn.close()
            pg_conn.close()
            print("Connections closed")
            
    except Exception as e:
        print(f"Fatal error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
