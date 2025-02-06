import json
import psycopg
from psycopg.rows import dict_row
from configparser import ConfigParser

def lambda_handler(event, context):
    print("**STARTING ASSIGN DOCUMENT TO GROUP FUNCTION**")
    print("Event:", json.dumps(event))
    
    try:
        group_id = event['pathParameters'].get('groupId')
        if not group_id:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Missing groupId in path parameters'})
            }
        
        body = json.loads(event['body'])
        doc_id = body.get('doc_id')
        
        if not doc_id:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Missing required parameter: doc_id'})
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
                INSERT INTO document_group_assignments (doc_id, group_id)
                VALUES (%s, %s)
                ON CONFLICT DO NOTHING
                RETURNING assignment_id, assigned_at;
            """
            with pg_conn.cursor() as cur:
                cur.execute(insert_sql, (doc_id, group_id))
                result = cur.fetchone()
                if not result:
                    return {
                        'statusCode': 409,
                        'body': json.dumps({'error': 'Document is already assigned to this group or invalid group/document ID'})
                    }
                assignment_id = result['assignment_id']
                assigned_at = result['assigned_at'].isoformat()
                print(f"Document {doc_id} assigned to group {group_id} with assignment ID {assignment_id}")
                
        except Exception as e:
            print(f"Error assigning document to group: {e}")
            return {
                'statusCode': 500,
                'body': json.dumps({'error': 'Failed to assign document to group'})
            }
        
        pg_conn.close()
        
        return {
    'statusCode': 201,
    'body': json.dumps({
        'message': 'Document assigned to group successfully',
        'assignment_id': str(assignment_id),
        'assigned_at': str(assigned_at)
    })
}

        
    except Exception as e:
        print(f"Fatal error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error'})
        }

