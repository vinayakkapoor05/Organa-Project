import json
import boto3
import os
import uuid
import datatier   
from configparser import ConfigParser
from PIL import Image, ImageEnhance, ImageOps
from io import BytesIO
import fitz  
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

def pdf_page_to_pil(page):
    pix = page.get_pixmap()
    img = Image.frombytes("RGB", [pix.width, pix.height], pix.samples)
    return img

def process_pdf(pdf_bytes):
  
    try:
        input_pdf = fitz.open(stream=pdf_bytes, filetype="pdf")
        if input_pdf.page_count == 0:
            raise Exception("No pages found in the PDF.")
        
        output_pdf = fitz.open()
        
        for index, page in enumerate(input_pdf):
            try:
                img = pdf_page_to_pil(page)
                
                img = ImageOps.exif_transpose(img)
                
                img = ImageOps.grayscale(img)
                
                img = ImageOps.autocontrast(img, cutoff=0.5)
                
                img = ImageEnhance.Sharpness(img).enhance(1.5)
                img = ImageEnhance.Contrast(img).enhance(1.2)
                
                img = ImageEnhance.Brightness(img).enhance(1.1)
                
                new_width, new_height = img.width // 2, img.height // 2
                img = img.resize((new_width, new_height))
                
                temp_img_path = f"/tmp/{uuid.uuid4()}.png"
                img.save(temp_img_path, "PNG")
                
                rect = fitz.Rect(0, 0, img.width, img.height)
                opage = output_pdf.new_page(width=img.width, height=img.height)
                opage.insert_image(rect, filename=temp_img_path)
                
                os.remove(temp_img_path)
            
            except Exception as img_proc_err:
                print(f"Error processing page {index}: {str(img_proc_err)}")
                continue
        
        return output_pdf.tobytes()
            
    except Exception as e:
        print(f"Error in PDF processing: {str(e)}")
        raise

def lambda_handler(event, context):
    try:
        print("**STARTING ORGANA PDF PROCESSOR**")
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
        
        dbConn = datatier.get_dbConn(rds_endpoint, rds_portnum, rds_username, rds_pwd, rds_dbname)
        
        for record in event['Records']:
            bucket = record['s3']['bucket']['name']
            key = record['s3']['object']['key']
            
            if not key.startswith('organa-original/'):
                print(f"Skipping file not in organa-original/: {key}")
                continue
                
            if not key.lower().endswith('.pdf'):
                print(f"Skipping non-PDF file: {key}")
                continue
                
            print(f"Processing PDF file: {key}")
            
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
                WHERE original_bucket_key = %s;
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
                WHERE original_bucket_key = %s;
                """
                try:
                    datatier.perform_action(dbConn, sql_update_status_fail, ['failed', key])
                    print(f"Updated status to 'failed' for key: {key}")
                except Exception as update_err:
                    print(f"Error updating status to 'failed' for key {key}: {str(update_err)}")
                continue
            
            sql_update_status = """
            UPDATE documents 
            SET status = %s, processed_date = NOW() 
            WHERE doc_id = %s;
            """
            try:
                affected_rows = datatier.perform_action(dbConn, sql_update_status, ['processing', doc_id])
                print(f"Rows affected by status update to 'processing': {affected_rows}")
                if affected_rows == 0:
                    print(f"No rows updated for doc_id: {doc_id}")
            except Exception as e:
                print(f"Exception during status update to 'processing' for doc_id {doc_id}: {str(e)}")
                continue  
            
            download_path = f"/tmp/{uuid.uuid4()}.pdf"
            try:
                s3_client.download_file(bucket, key, download_path)
                print(f"Downloaded file to {download_path}")
            except Exception as download_err:
                print(f"Error downloading file {key}: {str(download_err)}")
                # Update status to 'failed'
                sql_update_status_fail = """
                UPDATE documents 
                SET status = %s 
                WHERE doc_id = %s;
                """
                try:
                    datatier.perform_action(dbConn, sql_update_status_fail, ['failed', doc_id])
                    print(f"Updated status to 'failed' for doc_id: {doc_id}")
                except Exception as update_err:
                    print(f"Error updating status to 'failed' for doc_id {doc_id}: {str(update_err)}")
                continue
            
            try:
                with open(download_path, 'rb') as file:
                    processed_bytes = process_pdf(file.read())
                print(f"Processed PDF and generated output bytes")
            except Exception as process_err:
                print(f"Error processing PDF {download_path}: {str(process_err)}")
                sql_update_status_fail = """
                UPDATE documents 
                SET status = %s 
                WHERE doc_id = %s;
                """
                try:
                    datatier.perform_action(dbConn, sql_update_status_fail, ['failed', doc_id])
                    print(f"Updated status to 'failed' for doc_id: {doc_id}")
                except Exception as update_err:
                    print(f"Error updating status to 'failed' for doc_id {doc_id}: {str(update_err)}")
                continue
            
            processed_key = key.replace('organa-original/', 'organa-processed/')
            print(f"Processed S3 Bucket Key: {processed_key}")
            
            try:
                s3_client.put_object(
                    Bucket=bucket,
                    Key=processed_key,
                    Body=processed_bytes,
                    ContentType='application/pdf'
                )
                print(f"Uploaded processed PDF to {processed_key}")
            except Exception as upload_err:
                print(f"Error uploading processed file {processed_key}: {str(upload_err)}")
                sql_update_status_fail = """
                UPDATE documents 
                SET status = %s 
                WHERE doc_id = %s;
                """
                try:
                    datatier.perform_action(dbConn, sql_update_status_fail, ['failed', doc_id])
                    print(f"Updated status to 'failed' for doc_id: {doc_id}")
                except Exception as update_err:
                    print(f"Error updating status to 'failed' for doc_id {doc_id}: {str(update_err)}")
                continue
            
            sql_update_processed = """
            UPDATE documents 
            SET processed_bucket_key = %s, status = %s 
            WHERE doc_id = %s;
            """
            try:
                affected_rows = datatier.perform_action(dbConn, sql_update_processed, [processed_key, 'processed', doc_id])
                print(f"Rows affected by processing update: {affected_rows}")
                if affected_rows == 0:
                    print(f"No rows updated for doc_id: {doc_id}")
            except Exception as e:
                print(f"Exception during processing update for doc_id {doc_id}: {str(e)}")
                sql_update_status_fail = """
                UPDATE documents 
                SET status = %s 
                WHERE doc_id = %s;
                """
                try:
                    datatier.perform_action(dbConn, sql_update_status_fail, ['failed', doc_id])
                    print(f"Updated status to 'failed' for doc_id: {doc_id}")
                except Exception as update_err:
                    print(f"Error updating status to 'failed' for doc_id {doc_id}: {str(update_err)}")
                continue
            
            try:
                os.remove(download_path)
                print(f"Removed temporary file {download_path}")
            except Exception as remove_err:
                print(f"Error removing temporary file {download_path}: {str(remove_err)}")
            
            print(f"Successfully processed and uploaded: {processed_key}")
        
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
