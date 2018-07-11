-- declare test case
CREATE OR REPLACE FUNCTION fetchq_test__mnt_make_pending_01 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'IT WAS NOT POSSIBLE TO MAKE PENDING DOCUMENTS';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();
    PERFORM fetchq_queue_create('foo');

    -- insert dummy data & force the date in the past
    PERFORM fetchq_doc_push('foo', 'a1', 0, 0, NOW() + INTERVAL '1 milliseconds', '{}');
    UPDATE fetchq__foo__documents SET next_iteration = NOW() - INTERVAL '1 milliseconds';
    PERFORM fetchq_doc_push('foo', 'a2', 0, 0, NOW() + INTERVAL '1 seconds', '{}');
    PERFORM fetchq_doc_push('foo', 'a3', 0, 0, NOW() - INTERVAL '1 seconds', '{}');

    PERFORM fetchq_mnt_make_pending('foo', 100);
    PERFORM fetchq_metric_log_pack();

    -- run the test
    SELECT * INTO VAR_r FROM fetchq_metric_get('foo', 'pnd');
    IF VAR_r.current_value != 2 THEN
        RAISE EXCEPTION 'failed - %', VAR_testName;
    END IF;

    -- cleanup
    PERFORM fetchq_test_clean();

    passed = TRUE;
END; $$
LANGUAGE plpgsql;
