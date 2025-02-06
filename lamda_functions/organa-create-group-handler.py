import json
import psycopg
from psycopg.rows import dict_row
from configparser import ConfigParser
import uuid 

def lambda_handler(event, context):
    print("**STARTING CREATE GROUP FUNCTION**")
    print("Event:", json.dumps(event))
    
    try:
        body = json.loads(event['body'])
        group_name = body.get('group_name')
        description = body.get('description', '')
        
        if not group_name:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Missing required parameter: group_name'})
            }
        
        user_id = event['pathParameters'].get('userId')
        if not user_id:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Missing userId in path parameters'})
            }
        
        config = ConfigParser()
        config.read('organa-config.ini')
        
        pg_conn = psycopg.connect(
            f"host={config.get('postgres', 'endpoint')} "
            f"port={config.get('postgres', 'port_number')} "
            f"dbname={config.get('postgres', 'db_name')} "
            f"user={config.get('postgres', 'user_name')} "
            f"password={config.get('postgres', 'user_pwd')}",
            row_factory=dict_row,
            autocommit=True
        )
        
        try:
            insert_sql = """
                INSERT INTO document_groups (user_id, group_name, description)
                VALUES (%s, %s, %s)
                RETURNING group_id, created_at;
            """
            with pg_conn.cursor() as cur:
                cur.execute(insert_sql, (user_id, group_name, description))
                result = cur.fetchone()
                group_id = str(result['group_id'])   
                created_at = result['created_at'].isoformat()
                print(f"Group created with ID: {group_id}")
        
        except psycopg.errors.UniqueViolation:
            pg_conn.rollback()
            return {
                'statusCode': 409,
                'body': json.dumps({'error': 'Group name already exists for this user'})
            }
        except Exception as e:
            print(f"Error inserting into document_groups: {e}")
            return {
                'statusCode': 500,
                'body': json.dumps({'error': 'Failed to create group', 'details': str(e)})
            }
        
        pg_conn.close()
        
        return {
            'statusCode': 201,
            'body': json.dumps({
                'message': 'Group created successfully',
                'group_id': group_id,
                'created_at': created_at
            })
        }
    
    except Exception as e:
        print(f"Fatal error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error', 'details': str(e)})
        }
        