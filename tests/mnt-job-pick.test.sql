
CREATE OR REPLACE FUNCTION fetchq_test__mnt_job_pick_01 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'IT SHOULD BE POSSIBLE TO PICK A JOB FROM THE MAINTENANCE QUEUE';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();
    PERFORM fetchq_queue_create('foo');
    UPDATE fetchq_sys_jobs SET next_iteration = NOW() - INTERVAL '1s';

    -- run the test
    SELECT * INTO VAR_r FROM fetchq_mnt_job_pick('5m', 1);
    IF VAR_r.id IS NULL THEN
        RAISE EXCEPTION 'failed - %', VAR_testName;
    END IF;

    -- cleanup
    PERFORM fetchq_test_clean();
    passed = TRUE;
END; $$
LANGUAGE plpgsql;
