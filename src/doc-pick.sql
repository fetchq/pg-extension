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
	VAR_q VARCHAR;
	VAR_affectedRows INTEGER;
BEGIN
	VAR_q = FORMAT(
		'UPDATE fetchq_data.%I__docs SET status = 2, next_iteration = NOW() + $1::interval, attempts = attempts + 1 
		WHERE subject IN (
			SELECT subject FROM fetchq_data.%I__docs
			WHERE lock_upgrade IS NULL AND status = 1 AND version = $2 AND next_iteration <= NOW() 
			ORDER BY priority DESC, next_iteration ASC, attempts ASC 
			LIMIT $3 FOR UPDATE SKIP LOCKED
		) 
		RETURNING subject, payload, version, priority, attempts, iterations, created_at, last_iteration, next_iteration, lock_upgrade;', 
		PAR_queue, PAR_queue
	);

	-- RAISE EXCEPTION 'query: %', VAR_q;

	RETURN QUERY EXECUTE VAR_q
	USING PAR_duration, PAR_version, PAR_limit;

	GET DIAGNOSTICS VAR_affectedRows := ROW_COUNT;

	-- RAISE NOTICE 'attempt';
	-- RAISE NOTICE 'aff rows %', VAR_affectedRows;
	
	-- update counters
	PERFORM fetchq.metric_log_increment(PAR_queue, 'pkd', VAR_affectedRows);
	PERFORM fetchq.metric_log_increment(PAR_queue, 'act', VAR_affectedRows);
	PERFORM fetchq.metric_log_decrement(PAR_queue, 'pnd', VAR_affectedRows);

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