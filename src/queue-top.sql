
DROP FUNCTION IF EXISTS fetchq_catalog.fetchq_queue_top(CHARACTER VARYING, INTEGER, INTEGER, INTEGER);
CREATE OR REPLACE FUNCTION fetchq_catalog.fetchq_queue_top(
	PAR_queue VARCHAR,
    PAR_version INTEGER,
    PAR_limit INTEGER,
    PAR_offset INTEGER
) RETURNS TABLE(
	subject VARCHAR,
	payload JSONB,
	version INTEGER,
	priority INTEGER,
	attempts INTEGER,
	iterations INTEGER,
	created_at TIMESTAMP WITH TIME ZONE,
	last_iteration TIMESTAMP WITH TIME ZONE,
	next_iteration TIMESTAMP WITH TIME ZONE,
	lock_upgrade TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
	VAR_tableName VARCHAR = 'fetchq_catalog.fetchq__';
	VAR_q VARCHAR;
	VAR_r RECORD;
BEGIN

    -- return documents
	VAR_q = 'SELECT subject, payload, version, priority, attempts, iterations, created_at, last_iteration, next_iteration, lock_upgrade ';
	VAR_q = VAR_q || 'FROM fetchq_catalog.fetchq__%s__documents ';
	VAR_q = VAR_q || 'WHERE version = %s ';
	VAR_q = VAR_q || 'LIMIT %s OFFSET %s';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_version, PAR_limit, PAR_offset);
	RETURN QUERY EXECUTE VAR_q;

END; $$
LANGUAGE plpgsql;
