-- It should be possible to run a maintanance job for all the existing queues
CREATE OR REPLACE FUNCTION fetchq_test.mnt_01() RETURNS void AS $$
DECLARE
    VAR_testName VARCHAR = 'IT SHOULD BE POSSIBLE TO RUN A MAINTENANCE JOB FOR EVERYTHING';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq.queue_create('foo');
    PERFORM fetchq.queue_create('faa');

    -- insert dummy data & force the date in the past
    PERFORM fetchq.doc_push('foo', 'a1', 0, 0, NOW(), '{}');
    PERFORM fetchq.doc_push('foo', 'a2', 0, 0, NOW() + INTERVAL '1s', '{}');
    PERFORM fetchq.doc_push('foo', 'a3', 0, 0, NOW() - INTERVAL '1s', '{}');
    
    UPDATE fetchq_data.foo__docs
    SET next_iteration = NOW() - INTERVAL '1 milliseconds', attempts = 4
    WHERE subject = 'a1';

    UPDATE fetchq_data.foo__docs
    SET next_iteration = NOW() - INTERVAL '1 milliseconds'
    WHERE subject = 'a2';

    PERFORM fetchq.doc_pick('foo', 0, 3, '5m');

    UPDATE fetchq_data.foo__docs
    SET next_iteration = NOW() - INTERVAL '1 milliseconds'
    WHERE subject = 'a1';

    UPDATE fetchq_data.foo__docs
    SET next_iteration = NOW() - INTERVAL '1 milliseconds'
    WHERE subject = 'a2';

    -- run the maintenance
    SELECT * INTO VAR_r FROM fetchq.mnt();

    -- test maintenance output
    IF VAR_r.processed != 8 THEN
        RAISE EXCEPTION 'processed jobs should be 8, received %', VAR_r.processed;
    END IF;
    IF VAR_r.packed != 21 THEN
        RAISE EXCEPTION 'packed logs should be 35, received %', VAR_r.packed;
    END IF;

    -- run the test
    SELECT * INTO VAR_r FROM fetchq.metric_get('foo', 'act');
    IF VAR_r.current_value != 1 THEN
        RAISE EXCEPTION 'failed - %(active count)', VAR_testName;
    END IF;

    SELECT * INTO VAR_r FROM fetchq.metric_get('foo', 'kll');
    IF VAR_r.current_value != 1 THEN
        RAISE EXCEPTION 'failed - %(killed count)', VAR_testName;
    END IF;
END; $$
LANGUAGE plpgsql;

