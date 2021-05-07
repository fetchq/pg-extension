-- PICK AND LOCK A DOCUMENT THAT NEEDS TO BE EXECUTED NEXT
-- SELECT * FROM "fetchq"."doc_pick"('foo', 0, 1, '5m');
-- returns:
-- { document_structure }
DROP FUNCTION IF EXISTS fetchq.doc_pick(CHARACTER VARYING, INTEGER, INTEGER, CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq.doc_pick(
	PAR_queue VARCHAR,
	PAR_version INTEGER,
	PAR_limit INTEGER,
	PAR_duration VARCHAR
) RETURNS TABLE(
	subject VARCHAR,
	payload JSONB,
	version INTEGER,
	priority INTEGER,
	attempts INTEGER,
	iterations BIGINT,
	created_at TIMESTAMP WITH TIME ZONE,
	last_iteration TIMESTAMP WITH TIME ZONE,
	next_iteration TIMESTAMP WITH TIME ZONE,
	lock_upgrade TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
	VAR_tableName VARCHAR;
	VAR_tempTable VARCHAR;
	VAR_updateCtx VARCHAR;
	VAR_q VARCHAR;
	VAR_affectedRows INTEGER;
BEGIN
	-- get temporary table name
	VAR_tableName = FORMAT('fetchq_data.%s__docs', PAR_queue);
	VAR_tempTable = FORMAT('fetchq__%s__pick_table', PAR_queue);
	VAR_updateCtx = FORMAT('fetchq__%s__pick_ctx', PAR_queue);

	-- create temporary table
	VAR_q = FORMAT('CREATE TEMP TABLE %s(subject VARCHAR(50)) ON COMMIT DROP;', VAR_tempTable);
	EXECUTE VAR_q;

	-- perform lock on the rows
	VAR_q = 'WITH %s AS( ';
	VAR_q = VAR_q || 'UPDATE %s ';
	VAR_q = VAR_q || 'SET status = 2, next_iteration = NOW() + ''%s'', attempts = attempts + 1 ';
	VAR_q = VAR_q || 'WHERE subject IN( SELECT subject FROM %s ';
    VAR_q = VAR_q || 'WHERE lock_upgrade IS NULL AND status = 1 AND version = %s AND next_iteration < NOW() ';
	VAR_q = VAR_q || 'ORDER BY priority DESC, next_iteration ASC, attempts ASC ';
	VAR_q = VAR_q || 'LIMIT %s FOR UPDATE SKIP LOCKED) RETURNING subject) ';
	VAR_q = VAR_q || 'INSERT INTO %s(subject) ';
	VAR_q = VAR_q || 'SELECT subject FROM %s; ';
	VAR_q = FORMAT(VAR_q, VAR_updateCtx, VAR_tableName, PAR_duration, VAR_tableName, PAR_version, PAR_limit, VAR_tempTable, VAR_updateCtx);
	EXECUTE VAR_q;
	GET DIAGNOSTICS VAR_affectedRows := ROW_COUNT;

	-- RAISE NOTICE 'attempt';
	-- RAISE NOTICE 'aff rows %', VAR_affectedRows;
	
	-- update counters
	PERFORM fetchq.metric_log_increment(PAR_queue, 'pkd', VAR_affectedRows);
	PERFORM fetchq.metric_log_increment(PAR_queue, 'act', VAR_affectedRows);
	PERFORM fetchq.metric_log_decrement(PAR_queue, 'pnd', VAR_affectedRows);

	-- return documents
	VAR_q = 'SELECT subject, payload, version, priority, attempts, iterations, created_at, last_iteration, next_iteration, lock_upgrade ';
	VAR_q = VAR_q || 'FROM %s WHERE subject IN( SELECT subject ';
	VAR_q = VAR_q || 'FROM %s); ';
	VAR_q = FORMAT(VAR_q, VAR_tableName, VAR_tempTable);
	RETURN QUERY EXECUTE VAR_q;

	-- drop temporary table
	VAR_q = FORMAT('DROP TABLE %s;', VAR_tempTable);
	EXECUTE VAR_q;	

	EXCEPTION WHEN OTHERS THEN BEGIN END;
END; $$
LANGUAGE plpgsql;


-- PICK AND LOCK A SINGLE DOCUMENT THAT NEEDS TO BE EXECUTED NEXT
-- SELECT * FROM "fetchq"."doc_pick"('foo','5m');
-- returns:
-- { document_structure }
DROP FUNCTION IF EXISTS fetchq.doc_pick(CHARACTER VARYING, CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq.doc_pick(
	PAR_queue VARCHAR,
	PAR_duration VARCHAR
) RETURNS TABLE(
	subject VARCHAR,
	payload JSONB,
	version INTEGER,
	priority INTEGER,
	attempts INTEGER,
	iterations BIGINT,
	created_at TIMESTAMP WITH TIME ZONE,
	last_iteration TIMESTAMP WITH TIME ZONE,
	next_iteration TIMESTAMP WITH TIME ZONE,
	lock_upgrade TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
	RETURN QUERY SELECT * FROM "fetchq"."doc_pick"(PAR_queue, 0, 1, PAR_duration);
END; $$
LANGUAGE plpgsql;

-- PICK AND LOCK A SINGLE DOCUMENT THAT NEEDS TO BE EXECUTED NEXT (default lock vale)
-- SELECT * FROM "fetchq"."doc_pick"('foo');
-- returns:
-- { document_structure }
DROP FUNCTION IF EXISTS fetchq.doc_pick(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq.doc_pick(
	PAR_queue VARCHAR
) RETURNS TABLE(
	subject VARCHAR,
	payload JSONB,
	version INTEGER,
	priority INTEGER,
	attempts INTEGER,
	iterations BIGINT,
	created_at TIMESTAMP WITH TIME ZONE,
	last_iteration TIMESTAMP WITH TIME ZONE,
	next_iteration TIMESTAMP WITH TIME ZONE,
	lock_upgrade TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
	RETURN QUERY SELECT * FROM "fetchq"."doc_pick"(PAR_queue, 0, 1, '5m');
END; $$
LANGUAGE plpgsql;


-- PICK AND LOCK A LIST OF DOCUMENTS THAT NEEDS TO BE EXECUTED NEXT (default lock vale)
-- SELECT * FROM "fetchq"."doc_pick"('foo', 5);
-- returns:
-- { document_structure }
DROP FUNCTION IF EXISTS fetchq.doc_pick(CHARACTER VARYING, INTEGER);
CREATE OR REPLACE FUNCTION fetchq.doc_pick(
	PAR_queue VARCHAR,
	PAR_limit INTEGER
) RETURNS TABLE(
	subject VARCHAR,
	payload JSONB,
	version INTEGER,
	priority INTEGER,
	attempts INTEGER,
	iterations BIGINT,
	created_at TIMESTAMP WITH TIME ZONE,
	last_iteration TIMESTAMP WITH TIME ZONE,
	next_iteration TIMESTAMP WITH TIME ZONE,
	lock_upgrade TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
	RETURN QUERY SELECT * FROM "fetchq"."doc_pick"(PAR_queue, 0, PAR_limit, '5m');
END; $$
LANGUAGE plpgsql;