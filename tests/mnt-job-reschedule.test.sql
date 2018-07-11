
CREATE OR REPLACE FUNCTION fetchq_test__mnt_job_reschedule_01 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'IT SHOULD BE POSSIBLE TO RECHEDULE A JOB FOR THE MAINTENANCE QUEUE';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();
    PERFORM fetchq_queue_create('foo');
    UPDATE fetchq_sys_jobs SET next_iteration = NOW() - INTERVAL '1s';

    -- run the test
    SELECT * INTO VAR_r FROM fetchq_mnt_job_pick('5m', 1);
    SELECT * INTO VAR_r FROM fetchq_mnt_job_reschedule(VAR_r.id, '1m');
    IF VAR_r.success IS NULL THEN
        RAISE EXCEPTION 'failed - %', VAR_testName;
    END IF;

    -- cleanup
    PERFORM fetchq_test_clean();
    passed = TRUE;
END; $$
LANGUAGE plpgsql;
