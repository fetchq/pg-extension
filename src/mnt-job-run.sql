
DROP FUNCTION IF EXISTS fetchq_mnt_job_run(CHARACTER VARYING, INTEGER);
CREATE OR REPLACE FUNCTION fetchq_mnt_job_run (
    PAR_lockDuration VARCHAR,
	PAR_limit INTEGER,
    OUT success BOOLEAN,
    OUT processed INTEGER
) AS $$
DECLARE
    VAR_r RECORD;
	VAR_q VARCHAR;
    VAR_limit INTEGER;
    VAR_delay VARCHAR;
BEGIN
    success = true;
    processed = 0;

    FOR VAR_r IN
		SELECT 
            id, task, queue, 
            settings->'limit' as limit_records, 
            settings->'delay' as execution_delay,
            settings->'duration' as execution_duration
        FROM fetchq_mnt_job_pick(PAR_lockDuration, PAR_limit)
	LOOP
        -- RAISE NOTICE '###########################';
		-- RAISE NOTICE '%', VAR_r;

        -- default records limit & next execution delay
        IF VAR_r.limit_records IS NOT NULL THEN VAR_limit = VAR_r.limit_records; ELSE VAR_limit = 100; END IF;
        IF VAR_r.execution_delay IS NOT NULL THEN VAR_delay = VAR_r.execution_delay; ELSE VAR_delay = '5m'; END IF;

        -- set custom lock duration fro job's settings
        IF VAR_r.execution_duration IS NOT NULL THEN
            VAR_q = '';
            VAR_q = VAR_q || 'UPDATE fetchq_sys_jobs ';
            VAR_q = VAR_q || 'SET next_iteration = NOW() + INTERVAL ''%s'' ';
            VAR_q = VAR_q || 'WHERE id = %s;';
            VAR_q = FORMAT(VAR_q, VAR_r.execution_duration, VAR_r.id);
            EXECUTE VAR_q;
        END IF;

        -- run the specific task logic
        CASE
        WHEN VAR_r.task = 'lgp' THEN
            PERFORM fetchq_metric_log_pack();
        WHEN VAR_r.task = 'mnt' THEN
            PERFORM fetchq_mnt_run(VAR_r.queue, VAR_limit);
        WHEN VAR_r.task = 'drp' THEN
            PERFORM fetchq_queue_drop_metrics(VAR_r.queue);
            PERFORM fetchq_queue_drop_errors(VAR_r.queue);
        WHEN VAR_r.task = 'sts' THEN
            PERFORM fetchq_metric_snap(VAR_r.queue);
        ELSE
            RAISE NOTICE 'DONT KNOW TASK %', VAR_r.task;
        END CASE;

        -- reschedule job
        PERFORM fetchq_mnt_job_reschedule(VAR_r.id, VAR_delay);
        processed = processed + 1;
	END LOOP;

    EXCEPTION WHEN OTHERS THEN BEGIN
        success = false;
    END;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_mnt_job_run(INTEGER);
CREATE OR REPLACE FUNCTION fetchq_mnt_job_run (
	PAR_limit INTEGER,
    OUT success BOOLEAN,
    OUT processed INTEGER
) AS $$
DECLARE
    VAR_r RECORD;
	VAR_q VARCHAR;
    VAR_limit INTEGER;
    VAR_delay VARCHAR;
BEGIN
    SELECT * INTO VAR_r FROM fetchq_mnt_job_run('5m', PAR_limit) as t;
    success = VAR_r.success;
    processed = VAR_r.processed;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_mnt_job_run();
CREATE OR REPLACE FUNCTION fetchq_mnt_job_run (
    OUT success BOOLEAN,
    OUT processed INTEGER
) AS $$
DECLARE
    VAR_r RECORD;
	VAR_q VARCHAR;
    VAR_limit INTEGER;
    VAR_delay VARCHAR;
BEGIN
    SELECT * INTO VAR_r FROM fetchq_mnt_job_run(1) as t;
    success = VAR_r.success;
    processed = VAR_r.processed;
END; $$
LANGUAGE plpgsql;
