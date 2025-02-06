# Organa

**Organa** is a macOS application designed to capture, process, store, and retrieve academic and professional documents. The project leverages a serverless architecture using AWS services—including AWS Textract, Amazon S3, Amazon RDS (MySQL & PostgreSQL), and AWS Lambda—and integrates with the OpenAI API to generate and search text embeddings. The macOS application is built with SwiftUI and utilizes Apple Continuity Camera for seamless document capture.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Core Components](#core-components)  
   2.1 [Databases](#databases)  
   2.2 [S3 Buckets](#s3-buckets)  
   2.3 [AWS Lambda Functions](#aws-lambda-functions)
3. [Lambda Functions Setup](#lambda-functions-setup)  
   3.1 [Prepare Lambda Layers](#prepare-lambda-layers)  
   3.2 [Deploy Lambda Functions](#deploy-lambda-functions)  
   3.3 [Environment Variables](#environment-variables)
4. [Database Setup](#database-setup)  
   4.1 [MySQL (Amazon RDS)](#mysql-amazon-rds)  
   4.2 [PostgreSQL (Amazon RDS)](#postgresql-amazon-rds)
5. [API Gateway Configuration](#api-gateway-configuration)  
   5.1 [Document APIs](#document-apis)  
   5.2 [Group APIs](#group-apis)  
   5.3 [Search API](#search-api)
6. [Client Application Setup (macOS)](#client-application-setup-macos)  
   6.1 [Requirements](#requirements)  
   6.2 [Setup Steps](#setup-steps)
7. [Running the Application](#running-the-application)
8. [Architecture & Workflow (High-Level)](#architecture--workflow-high-level)
9. [Non-Trivial Operations](#non-trivial-operations)
10. [Additional Notes & Final Checklist](#additional-notes--final-checklist)
11. [Conclusion](#conclusion)

---

## 1. Project Overview

Organa is a macOS application that enables users to capture, store, and retrieve documents with a focus on academic and professional use. By leveraging AWS services like S3, Lambda, and Textract, plus OpenAI for embedding-based search, Organa streamlines the document management workflow.

---

## 2. Core Components

### 2.1 Databases

1. **MySQL (Amazon RDS)**
   - **Purpose:** Stores metadata related to documents, users, and groups.
   - **Key Tables:**
     - **Users** – Contains user details.
     - **Documents** – Tracks document metadata (e.g., status, S3 paths).

2. **PostgreSQL (Amazon RDS)**
   - **Purpose:** Stores text embeddings for efficient similarity-based searches and group data.
   - **Key Tables:**
     - **document_embeddings** – Stores numerical embeddings for text search.
     - **Groups** – Manages user-defined groups.
     - **Groups to Documents Linking** – Relationship table mapping documents to groups.

**Required Extension**  
Enable vector operations in PostgreSQL by installing **pgvector**:

```sql
CREATE EXTENSION pgvector;
```

### 2.2 S3 Buckets

Amazon S3 is used to store documents in different stages of processing:

- `organa-original/` – **Raw** user-uploaded documents.
- `organa-processed/` – **Processed** versions of documents (enhancements, deskewing, etc.).
- `organa-extracted-text/` – **Extracted text** from the documents.

### 2.3 AWS Lambda Functions

Organa uses **10 Lambda functions**, each responsible for specific tasks:

1. **organa-upload-handler**  
   - Uploads documents to `organa-original/` in S3.  
   - Updates document metadata in MySQL.

2. **organa-pdf-processing-handler**  
   - Enhances document images (deskewing, brightness, noise reduction).  
   - Stores the enhanced file in `organa-processed/`.

3. **organa-text-extraction-handler**  
   - Uses AWS Textract to extract text.  
   - Saves extracted text to `organa-extracted-text/`.

4. **organa-embeddings-handler**  
   - Generates text embeddings via the OpenAI API.  
   - Stores embeddings in PostgreSQL (`document_embeddings` table).

5. **organa-search-handler**  
   - Converts user search queries into embeddings.  
   - Performs similarity-based lookups in PostgreSQL.

6. **organa-create-group-handler**  
   - Creates new groups for organizing documents.

7. **organa-assign-group-handler**  
   - Assigns documents to specific groups.

8. **organa-list-group-handler**  
   - Retrieves all groups for a user.

9. **organa-retrieve-handler**  
   - Fetches metadata and file paths for all user documents.

10. **organa-detailed-retriever-handler**  
    - Retrieves detailed document information, including extracted text.

---

## 3. Lambda Functions Setup

### 3.1 Prepare Lambda Layers

Create and deploy the following **Lambda layers**:

1. **pymysql-pypdf-layer**  
   - **PyMySQL** (MySQL integration)  
   - **PyPDF2** (PDF handling)

2. **psycopg-layer**  
   - **psycopg2** (PostgreSQL integration)

3. **openai-numpy-layer**  
   - **openai** (OpenAI API calls)  
   - **numpy** (numerical arrays, often needed for embeddings)

4. **pillow-pymupdf-layer**  
   - **Pillow** (image processing)  
   - **PyMuPDF** (PDF manipulation)

Ensure all layers are uploaded to AWS Lambda in the same Region where the functions will reside.

### 3.2 Deploy Lambda Functions

Use the provided source code for each function and attach **the following layers**:

| **Lambda Function**                   | **Required Layers**                                    |
|---------------------------------------|---------------------------------------------------------|
| organa-text-extraction-handler        | pymysql-pypdf-layer                                    |
| organa-list-group-handler            | psycopg-layer                                          |
| organa-upload-handler                | pymysql-pypdf-layer                                    |
| organa-detailed-retriever-handler    | pymysql-pypdf-layer                                    |
| organa-search-handler                | psycopg-layer, openai-numpy-layer                      |
| organa-assign-group-handler          | psycopg-layer                                          |
| organa-retrieve-handler              | pymysql-pypdf-layer                                    |
| organa-embeddings-handler            | openai-numpy-layer, psycopg-layer, pymysql-pypdf-layer |
| organa-pdf-processing-handler        | pillow-pymupdf-layer, pymysql-pypdf-layer              |
| organa-create-group-handler          | psycopg-layer                                          |

### 3.3 Environment Variables

Configure environment variables for each Lambda function, including (but not limited to):

- **AWS credentials** (or appropriate IAM role) for S3 and Textract.  
- **Database connection strings** for MySQL and PostgreSQL.  
- **OpenAI API key** for `organa-embeddings-handler` and `organa-search-handler`.

Use AWS Systems Manager Parameter Store or AWS Secrets Manager for secure storage of sensitive values.

---

## 4. Database Setup

### 4.1 MySQL (Amazon RDS)

1. **Purpose:** Stores document metadata and user details.  
2. **Setup:** Use provided SQL scripts to create tables, such as:
   - **Users**  
   - **Documents**  
   - Any additional tables (e.g., for user roles or statuses).

### 4.2 PostgreSQL (Amazon RDS)

1. **Purpose:** Stores text embeddings for similarity searches and user-defined group data.  
2. **Setup:** Use the provided schema to create:
   - **document_embeddings**  
   - **Groups**  
   - **Groups to Documents Linking**  
3. **pgvector Extension:**

```sql
CREATE EXTENSION pgvector;
```

---

## 5. API Gateway Configuration

AWS API Gateway routes requests to Lambda functions. Configure and deploy these endpoints:

### 5.1 Document APIs

1. **POST** `/upload/{userId}`  
   - Invokes `organa-upload-handler` to upload a document.

2. **GET** `/documents/{userId}`  
   - Invokes `organa-retrieve-handler` to retrieve all documents for a user.

3. **GET** `/document/{docId}`  
   - Invokes `organa-detailed-retriever-handler` to fetch detailed info about a document.

### 5.2 Group APIs

1. **POST** `/groups/create/{userId}`  
   - Invokes `organa-create-group-handler` to create a new group.

2. **POST** `/groups/assign/{groupId}`  
   - Invokes `organa-assign-group-handler` to assign a document to a group.

3. **GET** `/groups/list/{userId}`  
   - Invokes `organa-list-group-handler` to list all groups for a user.

### 5.3 Search API

1. **GET** `/search/{userId}`  
   - Invokes `organa-search-handler` to search for documents based on user queries.

---

## 6. Client Application Setup (macOS)

Organa’s frontend is built with SwiftUI for macOS. It leverages **Apple Continuity Camera** for document capture.

### 6.1 Requirements

- **macOS 12.0 or later**  
- **Xcode 14.0 or later**

### 6.2 Setup Steps

1. **Open the Project**  
   - Open `Organa.xcodeproj` in Xcode.

2. **Configure Base URLs**  
   - In `DocumentManager.swift` and `SearchManager.swift`, set the `baseURL` to your API Gateway endpoint.

3. **Build and Run**  
   - Select your Mac (or a macOS Simulator) in Xcode.  
   - Click **Run** to build and launch the app.

4. **Why macOS?**  
   - The macOS platform allows using Apple Continuity Camera for multi-page document scanning.

---

## 7. Running the Application

1. **Start the Backend Services**  
   - Deploy and configure all Lambda functions (with environment variables).  
   - Ensure API Gateway endpoints are set up and tested.  
   - Verify MySQL and PostgreSQL RDS instances are running with correct schemas.

2. **Run the Client Application**  
   - Launch Organa from Xcode or from the compiled app.  
   - **Upload documents** to test the end-to-end workflow.  
   - **Search** for documents using natural language queries.  
   - **Create and assign groups** to organize documents.  
   - Use the **detailed retrieval** endpoint to confirm extracted text and metadata are accessible.

---

## 8. Architecture & Workflow (High-Level)

1. **Document Upload**  
   1. User uploads a file via `/upload/{userId}`.  
   2. Raw file goes to `organa-original/` in S3; MySQL stores metadata.

2. **Processing**  
   1. `organa-pdf-processing-handler` enhances the file.  
   2. Enhanced file is saved in `organa-processed/`; MySQL is updated.

3. **Text Extraction**  
   1. `organa-text-extraction-handler` extracts text using AWS Textract.  
   2. Extracted text is stored in `organa-extracted-text/`.

4. **Embedding Generation**  
   1. `organa-embeddings-handler` calls OpenAI to create embeddings.  
   2. Stores embeddings in PostgreSQL (`document_embeddings`).

5. **Searching**  
   1. User query hits `/search/{userId}`.  
   2. `organa-search-handler` converts the query to an embedding, searches via PostgreSQL.

6. **Grouping**  
   1. Create groups with `/groups/create/{userId}`.  
   2. Assign documents to groups with `/groups/assign/{groupId}`.  
   3. List groups with `/groups/list/{userId}`.

7. **Detailed Retrieval**  
   - `/document/{docId}` returns metadata, original/processed files, and extracted text.

---

## 9. Non-Trivial Operations

1. **PDF Processing**  
   - Deskewing, brightness adjustment, noise reduction using **Pillow** & **PyMuPDF**.

2. **Text Extraction**  
   - AWS Textract for accurate OCR on processed PDFs.

3. **Embedding & Search**  
   - **OpenAI** text embeddings + PostgreSQL **pgvector** for similarity searches.

4. **Grouping**  
   - Assign multiple documents to user-defined categories.

5. **Uploading**  
   - Mac app integrates with Apple Continuity Camera for capturing multi-page documents.

---

## 10. Additional Notes & Final Checklist

- **AWS Credentials & OpenAI Keys**: Use AWS Secrets Manager or Parameter Store to store secrets securely.  
- **organa-config.ini**: Ensure correct DB credentials, S3 bucket info, API keys, etc.  
- **Lambda Layers**: Double-check that layers (pymysql-pypdf, psycopg, openai-numpy, pillow-pymupdf) are uploaded and attached properly.  
- **Git Ignore**: Exclude sensitive info, build artifacts, and large files from version control.  
- **Connectivity**: Ensure Lambda has access to RDS (via VPC configuration or public access).  
- **Testing**: Validate each endpoint in API Gateway before deploying to production.

---

## 11. Conclusion

Following these instructions will help you deploy Organa—a serverless document capture and retrieval system that uses AWS Textract for text extraction and OpenAI for embedding-based search. The macOS SwiftUI client ties everything together with seamless document uploads (including Apple Continuity Camera integration), grouping, and retrieval.

Enjoy building and refining **Organa**!

