
-- RESCHEDULE AN ACTIVE DOCUMENT
-- returns:
-- { affected_rows: 1 }
DROP FUNCTION IF EXISTS fetchq.doc_reschedule(CHARACTER VARYING, CHARACTER VARYING, TIMESTAMP WITH TIME ZONE);
CREATE OR REPLACE FUNCTION fetchq.doc_reschedule(
	PAR_queue VARCHAR,
	PAR_subject VARCHAR,
	PAR_nextIteration TIMESTAMP WITH TIME ZONE,
	OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_tableName VARCHAR;
    VAR_lockName VARCHAR;
	VAR_q VARCHAR;
	VAR_iterations INTEGER;
	VAR_status INTEGER = 0;
BEGIN
	VAR_tableName = FORMAT('fetchq_data.%s__docs', PAR_queue);
	VAR_lockName = FORMAT('fetchq_lock_queue_%s', PAR_queue);

	-- pick right status based on nextIteration date
    IF PAR_nextIteration <= NOW() THEN
		VAR_status = 1;
	END IF;

	VAR_q = 'WITH %s AS( ';
	VAR_q = VAR_q || 'UPDATE %s AS lc SET ';
	VAR_q = VAR_q || 'status = %s, next_iteration = ''%s'', attempts = 0, iterations = lc.iterations + 1, last_iteration = NOW() ';
	VAR_q = VAR_q || 'WHERE subject IN( SELECT subject FROM %s WHERE subject = ''%s'' AND status = 2 LIMIT 1 ) RETURNING version) ';
	VAR_q = VAR_q || 'SELECT version FROM %s LIMIT 1;';
	VAR_q = FORMAT(VAR_q, VAR_lockName, VAR_tableName, VAR_status, PAR_nextIteration, VAR_tableName, PAR_subject, VAR_lockName);

--	raise log '%', VAR_q;

	EXECUTE VAR_q INTO VAR_iterations;
	GET DIAGNOSTICS affected_rows := ROW_COUNT;

	-- Update counters
	IF affected_rows > 0 THEN
		PERFORM fetchq.metric_log_increment(PAR_queue, 'prc', affected_rows);
		PERFORM fetchq.metric_log_increment(PAR_queue, 'res', affected_rows);
		PERFORM fetchq.metric_log_decrement(PAR_queue, 'act', affected_rows);

		-- Update correct counter based on the applied status
		IF VAR_status = 0 THEN
			PERFORM fetchq.metric_log_increment(PAR_queue, 'pln', affected_rows);
		ELSE
			PERFORM fetchq.metric_log_increment(PAR_queue, 'pnd', affected_rows);
		END IF;
	END IF;

	-- raise log 'UPDATE %, DOMAIN %, VERSION %', affectedRows, domainId, versionNum;

--	EXCEPTION WHEN OTHERS THEN BEGIN END;
END; $$
LANGUAGE plpgsql;

-- RESCHEDULE AN ACTIVE DOCUMENT
-- returns:
-- { affected_rows: 1 }
DROP FUNCTION IF EXISTS fetchq.doc_reschedule(CHARACTER VARYING, CHARACTER VARYING, TIMESTAMP WITH TIME ZONE, JSONB);
CREATE OR REPLACE FUNCTION fetchq.doc_reschedule(
	PAR_queue VARCHAR,
	PAR_subject VARCHAR,
	PAR_nextIteration TIMESTAMP WITH TIME ZONE,
	PAR_payload JSONB,
	OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_tableName VARCHAR;
    VAR_lockName VARCHAR;
	VAR_q VARCHAR;
	VAR_iterations INTEGER;
	VAR_status INTEGER = 0;
BEGIN
	VAR_tableName = FORMAT('fetchq_data.%s__docs', PAR_queue);
	VAR_lockName = FORMAT('fetchq_lock_queue_%s', PAR_queue);

	-- pick right status based on nextIteration date
    IF PAR_nextIteration <= NOW() THEN
		VAR_status = 1;
	END IF;

	VAR_q = 'WITH %s AS( ';
	VAR_q = VAR_q || 'UPDATE %s AS lc SET ';
	VAR_q = VAR_q || 'payload = ''%s'', status = %s, next_iteration = ''%s'', attempts = 0, iterations = lc.iterations + 1, last_iteration = NOW() ';
	VAR_q = VAR_q || 'WHERE subject IN( SELECT subject FROM %s WHERE subject = ''%s'' AND status = 2 LIMIT 1 ) RETURNING version) ';
	VAR_q = VAR_q || 'SELECT version FROM %s LIMIT 1;';
	VAR_q = FORMAT(VAR_q, VAR_lockName, VAR_tableName, PAR_payload, VAR_status, PAR_nextIteration, VAR_tableName, PAR_subject, VAR_lockName);

--	raise log '%', VAR_q;

	EXECUTE VAR_q INTO VAR_iterations;
	GET DIAGNOSTICS affected_rows := ROW_COUNT;

	-- Update counters
	IF affected_rows > 0 THEN
		PERFORM fetchq.metric_log_increment(PAR_queue, 'prc', affected_rows);
		PERFORM fetchq.metric_log_increment(PAR_queue, 'res', affected_rows);
		PERFORM fetchq.metric_log_decrement(PAR_queue, 'act', affected_rows);

		-- Update correct counter based on the applied status
		IF VAR_status = 0 THEN
			PERFORM fetchq.metric_log_increment(PAR_queue, 'pln', affected_rows);
		ELSE
			PERFORM fetchq.metric_log_increment(PAR_queue, 'pnd', affected_rows);
		END IF;
	END IF;

	-- raise log 'UPDATE %, DOMAIN %, VERSION %', affectedRows, domainId, versionNum;

--	EXCEPTION WHEN OTHERS THEN BEGIN END;
END; $$
LANGUAGE plpgsql;
