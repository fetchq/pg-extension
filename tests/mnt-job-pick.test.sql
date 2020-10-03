
CREATE OR REPLACE FUNCTION fetchq_test.fetchq_test__mnt_job_pick_01(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'IT SHOULD BE POSSIBLE TO PICK A JOB FROM THE MAINTENANCE QUEUE';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test.fetchq_test_init();
    PERFORM fetchq.queue_create('foo');
    UPDATE __fetchq_jobs SET next_iteration = NOW() - INTERVAL '1s';

    -- run the test
    SELECT * INTO VAR_r FROM fetchq.mnt_job_pick('5m', 1);
    IF VAR_r.id IS NULL THEN
        RAISE EXCEPTION 'failed - %', VAR_testName;
    END IF;


    passed = TRUE;
END; $$
LANGUAGE plpgsql;
