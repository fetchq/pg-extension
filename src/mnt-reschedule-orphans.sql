-- MAINTENANCE // RESCHEDULE ORPHANS
-- returns:
-- { affected_rows: 1 }
DROP FUNCTION IF EXISTS fetchq_mnt_reschedule_orphans(CHARACTER VARYING, INTEGER);
CREATE OR REPLACE FUNCTION fetchq_mnt_reschedule_orphans (
	PAR_queue VARCHAR,
	PAR_limit INTEGER,
	OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
	VAR_r RECORD;
BEGIN
	-- get the current attempts limit
	VAR_q = '';
	VAR_q = VAR_q || 'SELECT max_attempts FROM fetchq_sys_queues ';
	VAR_q = VAR_q || 'WHERE name = ''%s'' LIMIT 1';
	EXECUTE FORMAT(VAR_q, PAR_queue) INTO VAR_r;

	VAR_q = '';
	VAR_q = VAR_q || 'UPDATE fetchq__%s__documents SET status = 1 ';
	VAR_q = VAR_q || 'WHERE subject IN ( SELECT subject FROM fetchq__%s__documents ';
	VAR_q = VAR_q || 'WHERE lock_upgrade IS NULL AND status = 2 AND attempts < %s AND next_iteration < NOW() ';
	VAR_q = VAR_q || 'LIMIT %s FOR UPDATE );';
	EXECUTE FORMAT(VAR_q, PAR_queue, PAR_queue, VAR_r.max_attempts, PAR_limit);
	GET DIAGNOSTICS affected_rows := ROW_COUNT;

	PERFORM fetchq_metric_log_increment(PAR_queue, 'err', affected_rows);
	PERFORM fetchq_metric_log_increment(PAR_queue, 'orp', affected_rows);
	PERFORM fetchq_metric_log_increment(PAR_queue, 'pnd', affected_rows);
	PERFORM fetchq_metric_log_decrement(PAR_queue, 'act', affected_rows);

	EXCEPTION WHEN OTHERS THEN BEGIN
		affected_rows = NULL;
	END;
END; $$
LANGUAGE plpgsql;