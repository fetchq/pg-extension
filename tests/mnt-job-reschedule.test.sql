
CREATE OR REPLACE FUNCTION fetchq_test.mnt_job_reschedule_01(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'IT SHOULD BE POSSIBLE TO RECHEDULE A JOB FOR THE MAINTENANCE QUEUE';
    VAR_r RECORD;
BEGIN
    
    -- initialize test

    PERFORM fetchq.queue_create('foo');
    UPDATE fetchq.jobs SET next_iteration = NOW() - INTERVAL '1s';

    -- run the test
    SELECT * INTO VAR_r FROM fetchq.mnt_job_pick('5m', 1);
    SELECT * INTO VAR_r FROM fetchq.mnt_job_reschedule(VAR_r.id, '1m');
    IF VAR_r.success IS NULL THEN
        RAISE EXCEPTION 'failed - %', VAR_testName;
    END IF;


    passed = TRUE;
END; $$
LANGUAGE plpgsql;
