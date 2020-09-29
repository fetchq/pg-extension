-- MAINTENANCE // CREATE PENDINGS
-- returns:
-- { affected_rows: 1 }
DROP FUNCTION IF EXISTS fetchq.mnt_make_pending(CHARACTER VARYING, INTEGER);
CREATE OR REPLACE FUNCTION fetchq.mnt_make_pending(
	PAR_queue VARCHAR,
	PAR_limit INTEGER,
	OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
BEGIN
    VAR_q = '';
	VAR_q = VAR_q || 'UPDATE fetchq_data.%s__docs SET status = 1 ';
	VAR_q = VAR_q || 'WHERE subject IN( ';
	VAR_q = VAR_q || 'SELECT subject FROM fetchq_data.%s__docs ';
	VAR_q = VAR_q || 'WHERE lock_upgrade IS NULL AND status = 0 AND next_iteration < NOW() ';
	VAR_q = VAR_q || 'ORDER BY next_iteration ASC, attempts ASC ';
	VAR_q = VAR_q || 'LIMIT %s  ';
	VAR_q = VAR_q || 'FOR UPDATE); ';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue, PAR_limit);

	-- RAISE NOTICE '%', VAR_q;

	EXECUTE VAR_q;
	GET DIAGNOSTICS affected_rows := ROW_COUNT;

    -- RAISE NOTICE '%', affected_rows;

	PERFORM fetchq.metric_log_increment(PAR_queue, 'pnd', affected_rows);
	PERFORM fetchq.metric_log_decrement(PAR_queue, 'pln', affected_rows);

	-- emit worker notifications
	-- IF affected_rows > 0 THEN
	-- 	PERFORM pg_notify(FORMAT('fetchq_pnd_%s', PAR_queue), affected_rows::text);
	-- END IF;

	-- EXCEPTION WHEN OTHERS THEN BEGIN
	-- 	affected_rows = NULL;
	-- END;
END; $$
LANGUAGE plpgsql;
