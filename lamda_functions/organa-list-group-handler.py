import json
import psycopg
from psycopg.rows import dict_row
from configparser import ConfigParser
import os
import traceback
import uuid
from datetime import datetime

def convert_special_types(obj):
    if isinstance(obj, (uuid.UUID, datetime)):
        return str(obj)
    elif isinstance(obj, dict):
        return {k: convert_special_types(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [convert_special_types(item) for item in obj]
    return obj

def lambda_handler(event, context):
    print("**STARTING LIST GROUPS FUNCTION**")
    print("Full Event:", json.dumps(event))
    
    try:
        user_id = event.get('pathParameters', {}).get('userId')
        if not user_id:
            print("ERROR: Missing userId in path parameters")
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Missing userId in path parameters'})
            }
        
        config = ConfigParser()
        config_path = 'organa-config.ini'
        
        if not os.path.exists(config_path):
            print(f"ERROR: Config file {config_path} not found")
            return {
                'statusCode': 500,
                'body': json.dumps({'error': f'Configuration file {config_path} not found'})
            }
        
        config.read(config_path)
        
        if not config.has_section('postgres'):
            print("ERROR: 'postgres' section missing in config")
            return {
                'statusCode': 500,
                'body': json.dumps({'error': 'Invalid database configuration'})
            }
        
        required_keys = ['endpoint', 'port_number', 'db_name', 'user_name', 'user_pwd']
        missing_keys = [key for key in required_keys if not config.has_option('postgres', key)]
        if missing_keys:
            print(f"ERROR: Missing config keys: {missing_keys}")
            return {
                'statusCode': 500,
                'body': json.dumps({'error': f'Missing configuration keys: {missing_keys}'})
            }
        
        conn_params = {
            'host': config.get('postgres', 'endpoint'),
            'port': config.get('postgres', 'port_number'),
            'dbname': config.get('postgres', 'db_name'),
            'user': config.get('postgres', 'user_name'),
            'password': config.get('postgres', 'user_pwd')
        }
        
        try:
            pg_conn = psycopg.connect(
                f"host={conn_params['host']} "
                f"port={conn_params['port']} "
                f"dbname={conn_params['dbname']} "
                f"user={conn_params['user']} "
                f"password={conn_params['password']}",
                row_factory=dict_row,
                autocommit=True
            )
        except Exception as conn_err:
            print(f"CONNECTION ERROR: {str(conn_err)}")
            print(traceback.format_exc())
            return {
                'statusCode': 500,
                'body': json.dumps({'error': 'Failed to connect to database', 'details': str(conn_err)})
            }
        
        try:
            select_sql = """
                SELECT group_id, group_name, description, created_at
                FROM document_groups
                WHERE user_id = %s
                ORDER BY created_at DESC;
            """
            with pg_conn.cursor() as cur:
                cur.execute(select_sql, (user_id,))
                groups = cur.fetchall()
                
                groups = convert_special_types(groups)
                
                print(f"Retrieved {len(groups)} groups for user {user_id}")
                
        except Exception as query_err:
            print(f"QUERY ERROR: {str(query_err)}")
            print(traceback.format_exc())
            return {
                'statusCode': 500,
                'body': json.dumps({'error': 'Failed to retrieve groups', 'details': str(query_err)})
            }
        finally:
            pg_conn.close()
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'user_id': user_id,
                'groups': groups
            })
        }
        
    except Exception as e:
        print(f"FATAL ERROR: {str(e)}")
        print(traceback.format_exc())
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Unexpected internal server error', 'details': str(e)})
        }
        