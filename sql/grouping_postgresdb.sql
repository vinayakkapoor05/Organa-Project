CREATE TABLE document_groups (
    group_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(64) NOT NULL,
    group_name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, group_name) 
);


CREATE TABLE document_group_assignments (
    assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    doc_id UUID NOT NULL REFERENCES document_embeddings(doc_id) ON DELETE CASCADE,
    group_id UUID NOT NULL REFERENCES document_groups(group_id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(doc_id, group_id) 
);

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE document_groups TO "organa-read-write";
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE document_group_assignments TO "organa-read-write";

