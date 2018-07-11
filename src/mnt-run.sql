-- MAINTENANCE // WRAPPER FUNCTION
-- returns:
-- { activated_count: 1, rescheduled_count: 1, killed_count: 1 }
DROP FUNCTION IF EXISTS fetchq_mnt_run(CHARACTER VARYING, INTEGER);
CREATE OR REPLACE FUNCTION fetchq_mnt_run (
	PAR_queue VARCHAR,
	PAR_limit INTEGER,
	OUT activated_count INTEGER,
	OUT rescheduled_count INTEGER,
	OUT killed_count INTEGER
) AS $$
BEGIN
	SELECT t.affected_rows INTO killed_count FROM fetchq_mnt_mark_dead(PAR_queue, PAR_limit) AS t;
	SELECT t.affected_rows INTO rescheduled_count FROM fetchq_mnt_reschedule_orphans(PAR_queue, PAR_limit) AS t;
	SELECT t.affected_rows INTO activated_count FROM fetchq_mnt_make_pending(PAR_queue, PAR_limit) AS t;
END; $$
LANGUAGE plpgsql;


-- MAINTENANCE FUNCTION
-- run maintenance wrapper for all the registered queues
DROP FUNCTION IF EXISTS fetchq_mnt_run_all(INTEGER);
CREATE OR REPLACE FUNCTION fetchq_mnt_run_all(
	PAR_limit INTEGER
) 
RETURNS TABLE (
	queue VARCHAR,
	activated_count INTEGER,
	rescheduled_count INTEGER,
	killed_count INTEGER
) AS
$BODY$
DECLARE
	VAR_q RECORD;
	VAR_c RECORD;
BEGIN
	FOR VAR_q IN
		SELECT (name) FROM fetchq_sys_queues
	LOOP
		SELECT * FROM fetchq_mnt_run(VAR_q.name, PAR_limit) INTO VAR_c;
		queue = VAR_q.name;
		activated_count = VAR_c.activated_count;
		rescheduled_count = VAR_c.rescheduled_count;
		killed_count = VAR_c.killed_count;
		RETURN NEXT;
	END LOOP;
END;
$BODY$
LANGUAGE plpgsql;
