/**
 * Traces a subject across the entire queue system extracting
 * the workflow plus errors.
 */
CREATE OR REPLACE FUNCTION fetchq_catalog.fetchq_trace(
	PAR_subject VARCHAR,
    PAR_order VARCHAR
) RETURNS TABLE(
    step INTEGER,
	created_at TIMESTAMP WITH TIME ZONE,
	queue VARCHAR,
	type VARCHAR,
	info VARCHAR,
	details JSONB
)
AS $$
DECLARE
    VAR_q TEXT;
	VAR_tableName VARCHAR = 'fetchq_trace_' || REPLACE(uuid_generate_v4()::text, '-', '_' );
	VAR_queueTableName VARCHAR;
	VAR_info VARCHAR;
    VAR_queues RECORD;
    VAR_record RECORD;
    VAR_step INTEGER = 1;
BEGIN

    VAR_q = 'CREATE TEMP TABLE %s(step INTEGER, created_at TIMESTAMP WITH TIME ZONE, queue VARCHAR, type VARCHAR, info VARCHAR, details JSONB) ON COMMIT DROP';
    EXECUTE FORMAT(VAR_q, VAR_tableName);
	
	FOR VAR_queues IN
		SELECT * FROM fetchq.queues
	LOOP
		-- ingest documents
        VAR_queueTableName = CONCAT('fetchq_catalog.', VAR_queues.name, '__documents');
		FOR VAR_record IN
			EXECUTE FORMAT('SELECT * FROM %s WHERE subject = ''%s''', VAR_queueTableName, PAR_subject)
		LOOP
			VAR_info = CONCAT('status: ', VAR_record.status, '; attempts: ', VAR_record.attempts, '; iterations: ', VAR_record.iterations);
            VAR_q = 'INSERT INTO %s(step, created_at, queue, type, info, details) VALUES(%s, ''%s'', ''%s'', ''%s'', ''%s'', ''%s'')';
            EXECUTE FORMAT(VAR_q, VAR_tableName, VAR_step, VAR_record.created_at, VAR_queues.name, 'document', VAR_info, row_to_json(VAR_record));
            VAR_step = VAR_step + 1;
		END LOOP;
		
		-- ingest errors
		VAR_queueTableName = CONCAT('fetchq_catalog.', VAR_queues.name, '__errors');
		FOR VAR_record IN
			EXECUTE FORMAT('SELECT * FROM %s WHERE subject = ''%s''', VAR_queueTableName, PAR_subject)
		LOOP
            VAR_q = 'INSERT INTO %s(step, created_at, queue, type, info, details) VALUES(%s, ''%s'', ''%s'', ''%s'', ''%s'', ''%s'')';
            EXECUTE FORMAT(VAR_q, VAR_tableName, VAR_step, VAR_record.created_at, VAR_queues.name, 'error', VAR_record.message, row_to_json(VAR_record));
            VAR_step = VAR_step + 1;
		END LOOP;
		
	END LOOP;
	
	RETURN QUERY EXECUTE FORMAT('SELECT * FROM %s ORDER BY step %s', VAR_tableName, PAR_order);
END; $$
LANGUAGE plpgsql;

/**
 * Traces a subject across the entire queue system extracting
 * the workflow plus errors.
 */
CREATE OR REPLACE FUNCTION fetchq_catalog.fetchq_trace(
	PAR_subject VARCHAR
) RETURNS TABLE(
    step INTEGER,
	created_at TIMESTAMP WITH TIME ZONE,
	queue VARCHAR,
	type VARCHAR,
	info VARCHAR,
	details JSONB
)
AS $$
BEGIN
	RETURN QUERY SELECT * FROM fetchq_catalog.fetchq_trace(PAR_subject, 'ASC');
END; $$
LANGUAGE plpgsql;
