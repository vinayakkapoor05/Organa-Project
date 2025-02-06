CREATE TABLE documents (
    doc_id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL,
    processeddatafile VARCHAR(256),
    extractedtextpath VARCHAR(256),
    upload_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    embedding VECTOR,
    CONSTRAINT user_id_fk FOREIGN KEY (user_id) REFERENCES users(user_id)
);
CREATE USER 'organa-read-write' IDENTIFIED BY 'abc123!!';
CREATE USER 'organa-read-write' IDENTIFIED BY 'def456!!';


GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE document_group_assignments TO "organa-read-write";
