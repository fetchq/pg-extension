
DROP FUNCTION IF EXISTS fetchq_catalog.fetchq_destroy_with_terrible_consequences();
CREATE OR REPLACE FUNCTION fetchq_catalog.fetchq_destroy_with_terrible_consequences(
    OUT was_destroyed BOOLEAN
) AS $$
DECLARE
    VAR_q RECORD;
BEGIN
    DROP SCHEMA IF EXISTS fetchq_catalog CASCADE;

    -- drop all queues
    -- FOR VAR_q IN
	-- 	SELECT(name) FROM fetchq.queues
	-- LOOP
    --     PERFORM fetchq_catalog.fetchq_queue_drop(VAR_q.name);
	-- END LOOP;

    -- Queues Index
    -- DROP TABLE fetchq.queues CASCADE;

    -- Metrics Overview
    -- DROP TABLE fetchq.metrics CASCADE;

    -- Metrics Writes
    -- DROP TABLE fetchq.metrics_writes CASCADE;

    -- Maintenance Jobs
    -- DROP TABLE fetchq.jobs CASCADE;

    -- handle output with graceful fail support
	-- was_destroyed = TRUE;
    -- EXCEPTION WHEN OTHERS THEN BEGIN
	-- 	was_destroyed = FALSE;
	-- END;

END; $$
LANGUAGE plpgsql;
