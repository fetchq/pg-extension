

CREATE OR REPLACE FUNCTION fetchq_test.fetchq_test__doc_reject_01(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'COULD NOT REJECT A DOCUMENT';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test.fetchq_test_init();
    PERFORM fetchq.queue_create('foo');

    -- insert dummy data
    PERFORM fetchq.doc_push('foo', 'a1', 0, 1, NOW() - INTERVAL '1s', '{}');
    SELECT * INTO VAR_r FROM fetchq.doc_pick('foo', 0, 2, '5m');

    -- perform reschedule
    PERFORM fetchq.doc_reject('foo', 'a1', 'foo', '{"a":1}');
    PERFORM fetchq.mnt_run_all(100);
    PERFORM fetchq.metric_log_pack();

    -- get first document
    SELECT * INTO VAR_r from fetchq_catalog.foo__documents
    WHERE subject = 'a1'
    AND status = 1
    AND iterations = 1
    AND next_iteration >= NOW() + INTERVAL '300s';
    IF VAR_r.subject IS NULL THEN
        RAISE EXCEPTION 'failed - %(failed to find the document after reject)', VAR_testName;
    END IF;

    -- get the logged error message
    SELECT * INTO VAR_r from fetchq_catalog.foo__errors
    WHERE subject = VAR_r.subject
    AND message = 'foo'
    AND ref_id IS NULL;
    IF VAR_r.id IS NULL THEN
        RAISE EXCEPTION 'failed - %(failed to find error log)', VAR_testName;
    END IF;

    -- cleanup
    PERFORM fetchq_test.fetchq_test_clean();

    passed = TRUE;
END; $$
LANGUAGE plpgsql;




CREATE OR REPLACE FUNCTION fetchq_test.fetchq_test__doc_reject_02(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'COULD NOT REJECT A DOCUMENT';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test.fetchq_test_init();
    PERFORM fetchq.queue_create('foo');

    -- insert dummy data
    PERFORM fetchq.doc_push('foo', 'a1', 0, 1, NOW() - INTERVAL '1s', '{}');
    SELECT * INTO VAR_r FROM fetchq.doc_pick('foo', 0, 2, '5m');

    -- perform reschedule
    PERFORM fetchq.doc_reject('foo', 'a1', 'foo', '{"a":1}', 'xxx');
    PERFORM fetchq.mnt_run_all(100);
    PERFORM fetchq.metric_log_pack();

    -- get first document
    SELECT * INTO VAR_r from fetchq_catalog.foo__documents
    WHERE subject = 'a1'
    AND status = 1
    AND iterations = 1
    AND next_iteration >= NOW() + INTERVAL '300s';
    IF VAR_r.subject IS NULL THEN
        RAISE EXCEPTION 'failed - %(failed to find the document after reject)', VAR_testName;
    END IF;

    -- get the logged error message
    SELECT * INTO VAR_r from fetchq_catalog.foo__errors
    WHERE subject = VAR_r.subject
    AND message = 'foo'
    AND ref_id = 'xxx';
    IF VAR_r.id IS NULL THEN
        RAISE EXCEPTION 'failed - %(failed to find error log)', VAR_testName;
    END IF;

    -- cleanup
    PERFORM fetchq_test.fetchq_test_clean();

    passed = TRUE;
END; $$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION fetchq_test.fetchq_test__doc_reject_03(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'SHOULD MARK A DOCUMENT AS DEAT';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test.fetchq_test_init();
    PERFORM fetchq.queue_create('foo');
    PERFORM fetchq.queue_set_max_attempts('foo', 1);

    -- insert dummy data
    PERFORM fetchq.doc_push('foo', 'a1', 0, 1, NOW() - INTERVAL '1s', '{}');
    SELECT * INTO VAR_r FROM fetchq.doc_pick('foo', 0, 2, '5m');

    -- perform reschedule
    PERFORM fetchq.doc_reject('foo', 'a1', 'foo', '{"a":1}', 'xxx');
    PERFORM fetchq.mnt_run_all(100);
    PERFORM fetchq.metric_log_pack();

    -- get first document
    SELECT * INTO VAR_r from fetchq_catalog.foo__documents
    WHERE subject = 'a1'
    AND status = -1;
    IF VAR_r.subject IS NULL THEN
        RAISE EXCEPTION 'failed - %(failed to kill a document after reject)', VAR_testName;
    END IF;

    -- cleanup
    -- PERFORM fetchq_test.fetchq_test_clean();

    passed = TRUE;
END; $$
LANGUAGE plpgsql;
