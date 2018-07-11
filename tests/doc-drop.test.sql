
CREATE OR REPLACE FUNCTION fetchq_test__doc_drop_01 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'COULD NOT DROP A DOCUMENT';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();
    PERFORM fetchq_queue_create('foo');

    -- insert dummy data
    PERFORM fetchq_doc_push('foo', 'a1', 0, 1, NOW() - INTERVAL '1s', '{}');
    PERFORM fetchq_doc_pick('foo', 0, 2, '5m');

    -- perform reschedule
    PERFORM fetchq_doc_drop('foo', 'a1');
    PERFORM fetchq_mnt_run_all(100);
    PERFORM fetchq_metric_log_pack();

    -- get no docs
    SELECT * INTO VAR_r from fetchq__foo__documents
    WHERE subject = 'a1';
    IF VAR_r.subject IS NOT NULL THEN
        RAISE EXCEPTION 'failed - %', VAR_testName;
    END IF;

    -- cleanup
    PERFORM fetchq_test_clean();

    passed = TRUE;
END; $$
LANGUAGE plpgsql;