
CREATE OR REPLACE FUNCTION fetchq_test__metric_get_all_01 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'COULD NOT GET ALL METRICS';
    VAR_r RECORD;
    VAR_affectedRows INTEGER;
BEGIN

    -- initialize test
    PERFORM fetchq_test_init();

    -- set counters
    PERFORM fetchq_queue_create('foo');
    PERFORM fetchq_doc_push('foo', 'a1', 0, 1, NOW() - INTERVAL '1s', '{}');
    PERFORM fetchq_doc_pick('foo', 0, 2, '5m');
    PERFORM fetchq_queue_create('faa');
    PERFORM fetchq_doc_push('faa', 'a1', 0, 1, NOW() - INTERVAL '1s', '{}');
    SELECT * INTO VAR_r FROM fetchq_doc_pick('faa', 0, 2, '5m');
    PERFORM fetchq_doc_reschedule('faa', VAR_r.subject, NOW() + INTERVAL '1y', '{"a":1}');
    PERFORM fetchq_metric_log_pack();

    -- run the test
    PERFORM fetchq_metric_get_all();
    GET DIAGNOSTICS VAR_affectedRows := ROW_COUNT;
    
    -- test result rows
    IF VAR_affectedRows <> 2 THEN
        RAISE EXCEPTION 'failed - % (affected_rows, expected "2", got "%")', VAR_testName, VAR_affectedRows;
    END IF;

    -- cleanup test
    PERFORM fetchq_test_clean();
    passed = TRUE;
END; $$
LANGUAGE plpgsql;
