
CREATE OR REPLACE FUNCTION fetchq_test.doc_complete_01(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'COULD NOT COMPLETE A DOCUMENT';
    VAR_r RECORD;
BEGIN
    
    -- initialize test

    PERFORM fetchq.queue_create('foo');

    -- insert dummy data
    PERFORM fetchq.doc_push('foo', 'a1', 0, 1, NOW() - INTERVAL '1s', '{}');
    PERFORM fetchq.doc_pick('foo', 0, 2, '5m');

    -- perform reschedule
    PERFORM fetchq.doc_complete('foo', 'a1');
    PERFORM fetchq.mnt_run_all(100);
    PERFORM fetchq.metric_log_pack();

    -- -- get first document
    SELECT * INTO VAR_r from fetchq_data.foo__docs
    WHERE subject = 'a1'
    AND status = 3
    AND iterations = 1
    AND next_iteration >= '2970-01-01';
    IF VAR_r.subject IS NULL THEN
        RAISE EXCEPTION 'failed - %(failed to find the document after complete)', VAR_testName;
    END IF;

    passed = TRUE;
END; $$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fetchq_test.doc_complete_02(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'COULD NOT COMPLETE A DOCUMENT - WITH NEW PAYLOAD';
    VAR_r RECORD;
BEGIN
    
    -- initialize test

    PERFORM fetchq.queue_create('foo');

    -- insert dummy data
    PERFORM fetchq.doc_push('foo', 'a1', 0, 1, NOW() - INTERVAL '1s', '{}');
    PERFORM fetchq.doc_pick('foo', 0, 2, '5m');

    -- perform reschedule
    PERFORM fetchq.doc_complete('foo', 'a1', '{"a":22}');
    PERFORM fetchq.mnt_run_all(100);
    PERFORM fetchq.metric_log_pack();

    -- -- get first document
    SELECT * INTO VAR_r from fetchq_data.foo__docs
    WHERE subject = 'a1'
    AND status = 3
    AND iterations = 1
    AND next_iteration >= '2970-01-01';
    IF VAR_r.subject IS NULL THEN
        RAISE EXCEPTION 'failed - %(failed to find the document after complete)', VAR_testName;
    END IF;

    passed = TRUE;
END; $$
LANGUAGE plpgsql;