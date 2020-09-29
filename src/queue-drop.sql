
-- DROP A QUEUE
-- returns:
-- { was_dropped: TRUE }
DROP FUNCTION IF EXISTS fetchq.queue_drop(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq.queue_drop(
	PAR_queue VARCHAR,
	OUT was_dropped BOOLEAN,
	OUT queue_id INTEGER
) AS $$
DECLARE
	VAR_tableName VARCHAR = 'fetchq_data.';
	VAR_q VARCHAR;
	VAR_r RECORD;
BEGIN
	was_dropped = TRUE;
	VAR_tableName = VAR_tableName || PAR_queue;

	-- drop indexes
	-- PERFORM fetchq.queue_drop_indexes(PAR_queue);

	-- drop queue table
	VAR_q = 'DROP TABLE %s__docs CASCADE;';
	VAR_q = FORMAT(VAR_q, VAR_tableName);
	EXECUTE VAR_q;

	-- drop errors table
	VAR_q = 'DROP TABLE %s__logs CASCADE;';
	VAR_q = FORMAT(VAR_q, VAR_tableName);
	EXECUTE VAR_q;

	-- drop stats table
	VAR_q = 'DROP TABLE %s__metrics CASCADE;';
	VAR_q = FORMAT(VAR_q, VAR_tableName);
	EXECUTE VAR_q;

	-- drop domain namespace
	DELETE FROM fetchq.queues
	WHERE name = PAR_queue RETURNING id INTO VAR_r;
	queue_id = VAR_r.id;

	-- drop maintenance tasks
	DELETE FROM fetchq.jobs WHERE queue = PAR_queue;

	-- drop counters
	DELETE FROM fetchq.metrics
	WHERE queue = PAR_queue;

	-- drop metrics logs
	DELETE FROM fetchq.metrics_writes
	WHERE queue = PAR_queue;

	-- send out notifications
	PERFORM pg_notify('fetchq_queue_drop', PAR_queue);

	EXCEPTION WHEN OTHERS THEN BEGIN
		was_dropped = FALSE;
	END;
END; $$
LANGUAGE plpgsql;
