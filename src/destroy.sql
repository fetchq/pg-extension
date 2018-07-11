
DROP FUNCTION IF EXISTS fetchq_destroy_with_terrible_consequences();
CREATE OR REPLACE FUNCTION fetchq_destroy_with_terrible_consequences (
    OUT was_destroyed BOOLEAN
) AS $$
DECLARE
    VAR_q RECORD;
BEGIN

    -- drop all queues
    FOR VAR_q IN
		SELECT (name) FROM fetchq_sys_queues
	LOOP
        PERFORM fetchq_queue_drop(VAR_q.name);
	END LOOP;

    -- Queues Index
    DROP TABLE fetchq_sys_queues CASCADE;

    -- Metrics Overview
    DROP TABLE fetchq_sys_metrics CASCADE;

    -- Metrics Writes
    DROP TABLE fetchq_sys_metrics_writes CASCADE;

    -- Maintenance Jobs
    DROP TABLE fetchq_sys_jobs CASCADE;

    -- handle output with graceful fail support
	was_destroyed = TRUE;
    EXCEPTION WHEN OTHERS THEN BEGIN
		was_destroyed = FALSE;
	END;

END; $$
LANGUAGE plpgsql;
