
CREATE OR REPLACE FUNCTION fetchq_test.doc_drop_01(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'COULD NOT DROP A DOCUMENT';
    VAR_r RECORD;
BEGIN
    
    -- initialize test

    PERFORM fetchq.queue_create('foo');

    -- insert dummy data
    PERFORM fetchq.doc_push('foo', 'a1', 0, 1, NOW() - INTERVAL '1s', '{}');
    PERFORM fetchq.doc_pick('foo', 0, 2, '5m');

    -- perform reschedule
    PERFORM fetchq.doc_drop('foo', 'a1');
    PERFORM fetchq.mnt_run_all(100);
    PERFORM fetchq.metric_log_pack();

    -- get no docs
    SELECT * INTO VAR_r from fetchq_data.foo__docs
    WHERE subject = 'a1';
    IF VAR_r.subject IS NOT NULL THEN
        RAISE EXCEPTION 'failed - %', VAR_testName;
    END IF;

    passed = TRUE;
END; $$
LANGUAGE plpgsql;