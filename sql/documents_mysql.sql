CREATE TABLE document_processing (
    original_bucket_key VARCHAR(256),
    processed_bucket_key VARCHAR(256),
    extracted_text_bucket_key VARCHAR(256),
    status ENUM('uploaded', 'processing', 'processed', 'extracting', 'extracted', 'failed') NOT NULL,
    upload_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    processed_date DATETIME,
    extraction_date DATETIME
);

CREATE USER 'organa-read-only' IDENTIFIED BY 'abc123!!';
CREATE USER 'organa-read-write' IDENTIFIED BY 'def456!!';

GRANT SELECT, SHOW VIEW ON benfordapp.* 
      TO 'organa-read-only';
GRANT SELECT, SHOW VIEW, INSERT, UPDATE, DELETE, DROP, CREATE, ALTER ON benfordapp.* 
      TO 'organa-read-write';

