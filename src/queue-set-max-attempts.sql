
DROP FUNCTION IF EXISTS fetchq_queue_set_max_attempts(CHARACTER VARYING, INTEGER);
CREATE OR REPLACE FUNCTION fetchq_queue_set_max_attempts (
	PAR_queue VARCHAR,
	PAR_maxAttempts INTEGER,
	OUT affected_rows INTEGER,
	OUT was_reindexed BOOLEAN
) AS $$
DECLARE
	VAR_q VARCHAR;
	VAR_r RECORD;
BEGIN
	-- initial values
	affected_rows = 0;
	was_reindexed = true;

	-- change max_attempts in the table
	VAR_q = '';
	VAR_q = VAR_q || 'UPDATE fetchq_sys_queues ';
	VAR_q = VAR_q || 'SET max_attempts = %s  ';
	VAR_q = VAR_q || 'WHERE name = ''%s'' RETURNING current_version';
	VAR_q = FORMAT(VAR_q, PAR_maxAttempts, PAR_queue);
	EXECUTE VAR_q INTO VAR_r;
	GET DIAGNOSTICS affected_rows := ROW_COUNT;

	-- drop max_attempts related indexes
	VAR_q = 'DROP INDEX IF EXISTS fetchq_%s_for_orp_idx';
	EXECUTE FORMAT(VAR_q, PAR_queue);
	VAR_q = 'DROP INDEX IF EXISTS fetchq_%s_for_dod_idx';
	EXECUTE FORMAT(VAR_q, PAR_queue);

	-- re-index the table
	-- RAISE NOTICE '%', VAR_r.current_version;
	PERFORM fetchq_queue_create_indexes(PAR_queue, VAR_r.current_version, PAR_maxAttempts);

	EXCEPTION WHEN OTHERS THEN BEGIN
		was_reindexed = false;
	END;
END; $$
LANGUAGE plpgsql;
