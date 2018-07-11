
-- DROP A QUEUE
-- returns:
-- { was_dropped: TRUE }
DROP FUNCTION IF EXISTS fetchq_queue_drop(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_queue_drop (
	PAR_queue VARCHAR,
	OUT was_dropped BOOLEAN,
	OUT queue_id INTEGER
) AS $$
DECLARE
	VAR_tableName VARCHAR = 'fetchq__';
	VAR_q VARCHAR;
	VAR_r RECORD;
BEGIN
	was_dropped = TRUE;
	VAR_tableName = VAR_tableName || PAR_queue;

	-- drop indexes
	-- PERFORM fetchq_queue_drop_indexes(PAR_queue);

	-- drop queue table
	VAR_q = 'DROP TABLE %s__documents;';
	VAR_q = FORMAT(VAR_q, VAR_tableName);
	EXECUTE VAR_q;

	-- drop errors table
	VAR_q = 'DROP TABLE %s__errors;';
	VAR_q = FORMAT(VAR_q, VAR_tableName);
	EXECUTE VAR_q;

	-- drop stats table
	VAR_q = 'DROP TABLE %s__metrics;';
	VAR_q = FORMAT(VAR_q, VAR_tableName);
	EXECUTE VAR_q;

	-- drop domain namespace
	DELETE FROM fetchq_sys_queues
	WHERE name = PAR_queue RETURNING id INTO VAR_r;
	queue_id = VAR_r.id;

	-- drop maintenance tasks
	DELETE FROM fetchq_sys_jobs WHERE queue = PAR_queue;

	-- drop counters
	DELETE FROM fetchq_sys_metrics
	WHERE queue = PAR_queue;

	-- drop metrics logs
	DELETE FROM fetchq_sys_metrics_writes
	WHERE queue = PAR_queue;

	EXCEPTION WHEN OTHERS THEN BEGIN
		was_dropped = FALSE;
	END;
END; $$
LANGUAGE plpgsql;
