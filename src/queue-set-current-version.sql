
DROP FUNCTION IF EXISTS fetchq_queue_set_current_version(CHARACTER VARYING, INTEGER);
CREATE OR REPLACE FUNCTION fetchq_queue_set_current_version (
	PAR_queue VARCHAR,
	PAR_newVersion INTEGER,
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
	VAR_q = VAR_q || 'SET current_version = %s  ';
	VAR_q = VAR_q || 'WHERE name = ''%s'' RETURNING max_attempts';
	VAR_q = FORMAT(VAR_q, PAR_newVersion, PAR_queue);
	EXECUTE VAR_q INTO VAR_r;
	GET DIAGNOSTICS affected_rows := ROW_COUNT;

	-- drop max_attempts related indexes
	-- VAR_q = 'DROP INDEX IF EXISTS fetchq_%s_for_pick_idx';
	-- EXECUTE FORMAT(VAR_q, PAR_queue);
	-- VAR_q = 'DROP INDEX IF EXISTS fetchq_%s_for_pnd_idx';
	-- EXECUTE FORMAT(VAR_q, PAR_queue);

	-- re-index the table
	PERFORM fetchq_queue_create_indexes(PAR_queue, PAR_newVersion, VAR_r.max_attempts);

	EXCEPTION WHEN OTHERS THEN BEGIN
		was_reindexed = false;
	END;
END; $$
LANGUAGE plpgsql;
