-- declare test case
CREATE OR REPLACE FUNCTION fetchq_test__mnt_run_01 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'IT WAS NOT POSSIBLE TO RUN MAINTENANCE';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();
    PERFORM fetchq_queue_create('foo');

    -- insert dummy data & force the date in the past
    PERFORM fetchq_doc_push('foo', 'a1', 0, 0, NOW(), '{}');
    PERFORM fetchq_doc_push('foo', 'a2', 0, 0, NOW() + INTERVAL '1s', '{}');
    PERFORM fetchq_doc_push('foo', 'a3', 0, 0, NOW() - INTERVAL '1s', '{}');
    
    UPDATE fetchq__foo__documents
    SET next_iteration = NOW() - INTERVAL '1 milliseconds', attempts = 4
    WHERE subject = 'a1';

    UPDATE fetchq__foo__documents
    SET next_iteration = NOW() - INTERVAL '1 milliseconds'
    WHERE subject = 'a2';

    PERFORM fetchq_mnt_run('foo', 100);
    PERFORM fetchq_doc_pick('foo', 0, 3, '5m');

    UPDATE fetchq__foo__documents
    SET next_iteration = NOW() - INTERVAL '1 milliseconds'
    WHERE subject = 'a1';

    UPDATE fetchq__foo__documents
    SET next_iteration = NOW() - INTERVAL '1 milliseconds'
    WHERE subject = 'a2';

    PERFORM fetchq_mnt_run('foo', 100);
    PERFORM fetchq_metric_log_pack();

    -- run the test
    SELECT * INTO VAR_r FROM fetchq_metric_get('foo', 'act');
    IF VAR_r.current_value != 1 THEN
        RAISE EXCEPTION 'failed - % (active count)', VAR_testName;
    END IF;

    SELECT * INTO VAR_r FROM fetchq_metric_get('foo', 'kll');
    IF VAR_r.current_value != 1 THEN
        RAISE EXCEPTION 'failed - % (killed count)', VAR_testName;
    END IF;

    -- cleanup
    PERFORM fetchq_test_clean();

    passed = TRUE;
END; $$
LANGUAGE plpgsql;





-- declare test case
CREATE OR REPLACE FUNCTION fetchq_test__mnt_run_all_01 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'IT WAS NOT POSSIBLE TO RUN ALL MAINTENANCE';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();
    PERFORM fetchq_queue_create('foo');
    PERFORM fetchq_queue_create('faa');

    -- insert dummy data & force the date in the past
    PERFORM fetchq_doc_push('foo', 'a1', 0, 0, NOW(), '{}');
    PERFORM fetchq_doc_push('foo', 'a2', 0, 0, NOW() + INTERVAL '1s', '{}');
    PERFORM fetchq_doc_push('foo', 'a3', 0, 0, NOW() - INTERVAL '1s', '{}');
    PERFORM fetchq_doc_push('faa', 'a1', 0, 0, NOW(), '{}');
    PERFORM fetchq_doc_push('faa', 'a2', 0, 0, NOW() + INTERVAL '1s', '{}');
    PERFORM fetchq_doc_push('faa', 'a3', 0, 0, NOW() - INTERVAL '1s', '{}');

    PERFORM fetchq_mnt_run_all(100);
    PERFORM fetchq_metric_log_pack();

    -- run the test
    -- SELECT * INTO VAR_r FROM fetchq_metric_get('foo', 'act');
    -- IF VAR_r.current_value != 1 THEN
    --     RAISE EXCEPTION 'failed - % (active count)', VAR_testName;
    -- END IF;

    -- SELECT * INTO VAR_r FROM fetchq_metric_get('foo', 'kll');
    -- IF VAR_r.current_value != 1 THEN
    --     RAISE EXCEPTION 'failed - % (killed count)', VAR_testName;
    -- END IF;

    -- cleanup
    PERFORM fetchq_test_clean();

    passed = TRUE;
END; $$
LANGUAGE plpgsql;
