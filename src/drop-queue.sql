
-- DROP A QUEUE
-- returns:
-- { was_dropped: TRUE }
DROP FUNCTION IF EXISTS fetchq_drop_queue(character varying);
CREATE OR REPLACE FUNCTION fetchq_drop_queue (
	domainStr VARCHAR,
	OUT was_dropped BOOLEAN
) AS $$
DECLARE
	table_name VARCHAR = 'fetchq__';
	drop_query VARCHAR;
BEGIN
	was_dropped = TRUE;
	table_name = table_name || domainStr;

	-- drop indexes
	-- PERFORM fetchq_drop_queue_indexes(domainStr);

	-- drop queue table
	drop_query = 'DROP TABLE %s__documents;';
	drop_query = FORMAT(drop_query, table_name);
	EXECUTE drop_query;

	-- drop errors table
	drop_query = 'DROP TABLE %s__errors;';
	drop_query = FORMAT(drop_query, table_name);
	EXECUTE drop_query;

	-- drop stats table
	drop_query = 'DROP TABLE %s__metrics;';
	drop_query = FORMAT(drop_query, table_name);
	EXECUTE drop_query;

	-- drop domain namespace
	DELETE FROM fetchq_sys_queues
	WHERE name = domainStr;

	-- drop maintenance tasks
	DELETE FROM fetchq_sys_jobs WHERE subject = domainStr;

	-- drop counters
	-- DELETE FROM lq__metrics
	-- WHERE queue = domainStr;

	-- drop metrics logs
	-- DELETE FROM lq__metrics_writes
	-- WHERE queue = domainStr;

	EXCEPTION WHEN OTHERS THEN BEGIN
		was_dropped = FALSE;
	END;
END; $$
LANGUAGE plpgsql;
