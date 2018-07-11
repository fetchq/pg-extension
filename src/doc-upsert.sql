-- PUSH A SINGLE DOCUMENT
DROP FUNCTION IF EXISTS fetchq_doc_upsert(CHARACTER VARYING, CHARACTER VARYING, INTEGER, INTEGER, TIMESTAMP WITH TIME ZONE, JSONB);
CREATE OR REPLACE FUNCTION fetchq_doc_upsert (
    PAR_queue VARCHAR,
    PAR_subject VARCHAR,
    PAR_version INTEGER,
    PAR_priority INTEGER,
    PAR_nextIteration TIMESTAMP WITH TIME ZONE,
    PAR_payload JSONB,
    OUT queued_docs INTEGER,
    OUT updated_docs INTEGER
) AS $$
DECLARE
    VAR_r RECORD;
	VAR_q VARCHAR;
    VAR_status INTEGER = 0;
BEGIN
    queued_docs = 0;
    updated_docs = 0;

    SELECT * INTO VAR_r FROM fetchq_doc_push(PAR_queue, PAR_subject, PAR_version, PAR_priority, PAR_nextIteration, PAR_payload);
    queued_docs = VAR_r.queued_docs;

    IF queued_docs = 0 THEN
        VAR_q = '';
        VAR_q = VAR_q || 'UPDATE fetchq__%s__documents SET ';
        VAR_q = VAR_q || 'priority = %s, ';
        VAR_q = VAR_q || 'payload = ''%s'', ';
        VAR_q = VAR_q || 'next_iteration = ''%s'' ';
        VAR_q = VAR_q || 'WHERE subject = ''%s'' AND lock_upgrade IS NULL AND status <> 2';
        VAR_q = FORMAT(VAR_q, PAR_queue, PAR_priority, PAR_payload, PAR_nextIteration, PAR_subject);

        EXECUTE VAR_q;
        GET DIAGNOSTICS updated_docs := ROW_COUNT;
    END IF;

    -- handle exception
	-- EXCEPTION WHEN OTHERS THEN BEGIN
	-- 	queued_docs = 0;
	-- END;
END; $$
LANGUAGE plpgsql;