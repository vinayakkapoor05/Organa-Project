import json
import os
from typing import List, Dict
import numpy as np
import openai
import psycopg
from psycopg.rows import dict_row
from configparser import ConfigParser

def create_embedding(text: str) -> List[float]:
    response = openai.Embedding.create(
        input=text,
        model="text-embedding-ada-002"
    )
    return response.data[0].embedding

def cosine_similarity(a: List[float], b: List[float]) -> float:
    a = np.array(a)
    b = np.array(b)
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))

def search_documents(conn, user_id: str, query_embedding: List[float], limit: int = 5, similarity_threshold: float = 0.2) -> List[Dict]:
    check_user_sql = """
    SELECT COUNT(*) as embedding_count 
    FROM document_embeddings 
    WHERE user_id = %s
    """
    
    try:
        with conn.cursor() as cur:
            cur.execute(check_user_sql, (user_id,))
            user_embedding_count = cur.fetchone()['embedding_count']
            print(f"Total embeddings for user {user_id}: {user_embedding_count}")
            
            if user_embedding_count == 0:
                print(f"No embeddings found for user {user_id}")
                return []

        sql = """
        WITH similarity_scores AS (
            SELECT 
                doc_id,
                processeddatafile,
                extractedtextpath,
                1 - (embedding <-> %s::vector) AS similarity
            FROM document_embeddings
            WHERE user_id = %s
        )
        SELECT 
            doc_id,
            processeddatafile, 
            extractedtextpath, 
            similarity 
        FROM similarity_scores
        WHERE similarity >= %s
        ORDER BY similarity DESC
        LIMIT %s
        """
        
        with conn.cursor() as cur:
            cur.execute(sql, (query_embedding, user_id, similarity_threshold, limit))
            results = cur.fetchall()
            
            print(f"Returned {len(results)} results with threshold {similarity_threshold}")
            for result in results:
                print(f"Result - File: {result['processeddatafile']}, Similarity: {result['similarity']}")
            
        return [{
            'doc_id': str(row['doc_id']),
            'file_path': row['processeddatafile'],
            'extracted_text_path': row['extractedtextpath'],
            'similarity_score': float(row['similarity'])
        } for row in results]
    except Exception as e:
        print(f"Error in search_documents: {str(e)}")
        raise
def lambda_handler(event, context):
    print("Starting document search")
    
    try:
        if 'pathParameters' not in event or 'userid' not in event['pathParameters']:
            print("Error: Missing userId in path parameters")
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Missing userId in path parameters'})
            }
            
        if 'queryStringParameters' not in event or not event['queryStringParameters'] or 'query' not in event['queryStringParameters']:
            print("Error: Missing required parameter: query")
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Missing required parameter: query'})
            }
                
        params = event['queryStringParameters']
        query = params['query']
        user_id = event['pathParameters']['userid']
        limit = int(params.get('limit', 5))
        similarity_threshold = float(params.get('threshold', 0.1))  
        
        config = ConfigParser()
        config.read('organa-config.ini')
        
        openai.api_key = config.get('openai', 'api_key')
        
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
            query_embedding = create_embedding(query)
            print(f"Generated query embedding for: {query}")
            print(f"Embedding length: {len(query_embedding)}")
            print(f"First few embedding values: {query_embedding[:10]}")
            
            with pg_conn.cursor() as cur:
                cur.execute("SELECT COUNT(*) as total_embeddings FROM document_embeddings")
                total_embeddings = cur.fetchone()['total_embeddings']
                print(f"Total embeddings in database: {total_embeddings}")
            
            results = search_documents(pg_conn, user_id, query_embedding, limit, similarity_threshold)
            
            print(f"Query: {query}")
            print(f"User ID: {user_id}")
            print(f"Limit: {limit}")
            print(f"Similarity Threshold: {similarity_threshold}")
            
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'query': query,
                    'results': results,
                    'total_results': len(results),
                    'total_embeddings': total_embeddings  
                })
            }
            
        finally:
            pg_conn.close()
            print("Connection closed")
            
    except Exception as e:
        print(f"Fatal error: {str(e)}")
        import traceback
        traceback.print_exc()  
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
        