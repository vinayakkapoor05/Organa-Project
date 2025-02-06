import json
import boto3
import os
import uuid
import base64
import pathlib
import datatier 
from configparser import ConfigParser

def lambda_handler(event, context):
    try:
        print("**STARTING ORGANA UPLOAD HANDLER**")
        
        config_file = 'organa-config.ini'
        os.environ['AWS_SHARED_CREDENTIALS_FILE'] = config_file
        
        configur = ConfigParser()
        configur.read(config_file)
        
        s3_profile = 's3readwrite'
        boto3.setup_default_session(profile_name=s3_profile)
        
        bucketname = configur.get('s3', 'bucket_name')
        s3 = boto3.resource('s3')
        bucket = s3.Bucket(bucketname)
        
        rds_endpoint = configur.get('rds', 'endpoint')
        rds_portnum = int(configur.get('rds', 'port_number'))
        rds_username = configur.get('rds', 'user_name')
        rds_pwd = configur.get('rds', 'user_pwd')
        rds_dbname = configur.get('rds', 'db_name')
        
        print("**Accessing event/pathParameters**")
        userid = None
        if "userid" in event:
            userid = event["userid"]
        elif "pathParameters" in event and "userid" in event["pathParameters"]:
            userid = event["pathParameters"]["userid"]
        else:
            raise Exception("User ID not provided in event or pathParameters")
        
        print("User ID:", userid)
        
        print("**Parsing request body**")
        if "body" not in event:
            raise Exception("No body found in event")
        
        body = json.loads(event["body"])
        
        filename = body.get("filename")
        datastr = body.get("data")
        
        if not filename or not datastr:
            raise Exception("Filename or data not found in request body")
        
        print("Filename:", filename)
        
        print("**Decoding and saving file locally**")
        base64_bytes = datastr.encode()
        file_bytes = base64.b64decode(base64_bytes)
        
        local_filename = "/tmp/uploaded_file"
        with open(local_filename, 'wb') as file:
            file.write(file_bytes)
        
        print("**Verifying user ID**")
        dbConn = datatier.get_dbConn(rds_endpoint, rds_portnum, rds_username, rds_pwd, rds_dbname)
        sql_verify = "SELECT * FROM users WHERE userid = %s;"
        user_row = datatier.retrieve_one_row(dbConn, sql_verify, [userid])
        
        if not user_row:
            raise Exception("No such user found in database")
        
        username = user_row[1]  
        print("User verified:", username)
        
        print("**Preparing S3 upload**")
        basename = pathlib.Path(filename).stem
        extension = pathlib.Path(filename).suffix
        
        if extension.lower() not in [".pdf", ".docx", ".png", ".jpg"]:
            raise Exception("Unsupported file type")
        
        doc_id = str(uuid.uuid4())
        
        bucket_key = f"organa-original/{username}/{basename}-{doc_id}{extension}"
        print("S3 Bucket Key:", bucket_key)
        
        print("**Uploading to S3**")
        bucket.upload_file(
            local_filename, 
            bucket_key, 
            ExtraArgs={'ContentType': 'application/octet-stream'}
        )
        
        print("**Inserting document record into database**")
        sql_insert = """
        INSERT INTO documents (
            doc_id, 
            userid, 
            original_bucket_key, 
            processed_bucket_key, 
            extracted_text_bucket_key, 
            status, 
            upload_date
        )
        VALUES (%s, %s, %s, %s, %s, %s, NOW());
        """
        datatier.perform_action(dbConn, sql_insert, [
            doc_id, 
            userid, 
            bucket_key, 
            None, 
            None, 
            'uploaded'
        ])
        
        print("**Upload complete**")
        return {
            'statusCode': 200,
            'body': json.dumps({
                "message": "Upload successful", 
                "file_path": bucket_key,
                "doc_id": doc_id
            })
        }
    
    except Exception as err:
        print("**ERROR**")
        print(str(err))
        return {
            'statusCode': 500,
            'body': json.dumps({"error": str(err)})
        }
