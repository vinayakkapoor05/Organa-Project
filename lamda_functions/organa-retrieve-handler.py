
import json
import datatier
from configparser import ConfigParser

def lambda_handler(event, context):
    try:
        print("**STARTING ORGANA DOCUMENT LIST HANDLER**")
        
        config_file = 'organa-config.ini'
        configur = ConfigParser()
        configur.read(config_file)
        
        rds_endpoint = configur.get('rds', 'endpoint')
        rds_portnum = int(configur.get('rds', 'port_number'))
        rds_username = configur.get('rds', 'user_name')
        rds_pwd = configur.get('rds', 'user_pwd')
        rds_dbname = configur.get('rds', 'db_name')
        
        dbConn = datatier.get_dbConn(rds_endpoint, rds_portnum, rds_username, rds_pwd, rds_dbname)
        
        userid = event.get("pathParameters", {}).get("userid")
        
        if not userid:
            raise ValueError("Missing required parameter: userid")
        
        sql = """
            SELECT doc_id, original_bucket_key, upload_date, status
            FROM documents
            WHERE userid = %s
            ORDER BY upload_date DESC;
        """
        rows = datatier.retrieve_all_rows(dbConn, sql, [userid])
        
        documents = [
            {
                "documentid": row[0],
                "originaldatafile": row[1],
                "upload_date": row[2].strftime("%Y-%m-%d %H:%M:%S"),
                "status": row[3]
            }
            for row in rows
        ]
        
        return {
            "statusCode": 200,
            "body": json.dumps({"documents": documents})
        }
    except Exception as e:
        print(f"Error: {e}")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }


