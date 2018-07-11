

CREATE OR REPLACE FUNCTION fetchq_test__doc_push_01 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'SHOULD BE ABLE TO QUEUE A SINGLE DOCUMENT WITH FUTURE SCHEDULE';
	VAR_queuedDocs INTEGER;
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();
    PERFORM fetchq_queue_create('foo');

    -- should be able to queue a document with future schedule
    SELECT * INTO VAR_queuedDocs FROM fetchq_doc_push('foo', 'a1', 0, 0, NOW() + INTERVAL '1m', '{}');
    IF VAR_queuedDocs <> 1 THEN
        RAISE EXCEPTION 'failed - %', VAR_testName;
    END IF;

    SELECT * INTO VAR_r FROM fetchq__foo__documents WHERE subject = 'a1';
    IF VAR_r.status <> 0 THEN
        RAISE EXCEPTION 'failed - % (Wrong status was computed for the document)', VAR_testName;
    END IF;

    -- checkout logs
    PERFORM fetchq_metric_log_pack();
    SELECT * INTO VAR_r FROM fetchq_metric_get('foo', 'pln');
    IF VAR_r.current_value <> 1 THEN
        RAISE EXCEPTION 'failed - % (Wrong planned documents count)', VAR_testName;
    END IF;

    -- cleanup test
    PERFORM fetchq_test_clean();

    passed = TRUE;
END; $$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION fetchq_test__doc_push_02 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'SHOULD BE ABLE TO QUEUE A SINGLE DOCUMENT WITH PAST SCHEDULE';
	VAR_queuedDocs INTEGER;
    VAR_r RECORD;
BEGIN

    -- initialize test
    PERFORM fetchq_test_init();
    PERFORM fetchq_queue_create('foo');

    -- should be able to queue a document with past schedule
    SELECT * INTO VAR_queuedDocs FROM fetchq_doc_push('foo', 'a1', 0, 0, NOW() - INTERVAL '1m', '{}');
    IF VAR_queuedDocs <> 1 THEN
        RAISE EXCEPTION 'failed - %', VAR_testName;
    END IF;

    SELECT * INTO VAR_r FROM fetchq__foo__documents WHERE subject = 'a1';
    IF VAR_r.status <> 1 THEN
        RAISE EXCEPTION 'failed - % (Wrong status was computed for the document)', VAR_testName;
    END IF;

    -- checkout logs
    PERFORM fetchq_metric_log_pack();
    SELECT * INTO VAR_r FROM fetchq_metric_get('foo', 'pnd');
    IF VAR_r.current_value <> 1 THEN
        RAISE EXCEPTION 'failed - % (Wrong planned documents count)', VAR_testName;
    END IF;

    -- cleanup test
    PERFORM fetchq_test_clean();

    passed = TRUE;
END; $$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fetchq_test__doc_push_03 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'SHOULD BE ABLE TO QUEUE MULTIPLE DOCUMENTS';
	VAR_queuedDocs INTEGER;
    VAR_r RECORD;
BEGIN

    -- initialize test
    PERFORM fetchq_test_init();
    PERFORM fetchq_queue_create('foo');

    SELECT * INTO VAR_queuedDocs FROM fetchq_doc_push( 'foo', 0, NOW(), '( ''a1'', 0, ''{"a":1}'', {DATA}), (''a2'', 1, ''{"a":2}'', {DATA} )');
    IF VAR_queuedDocs <> 2 THEN
        RAISE EXCEPTION 'failed - %', VAR_testName;
    END IF;

    -- checkout logs
    PERFORM fetchq_metric_log_pack();
    SELECT * INTO VAR_r FROM fetchq_metric_get('foo', 'pnd');
    IF VAR_r.current_value <> 2 THEN
        RAISE EXCEPTION 'failed - % (Wrong pending documents count when adding multiple documents)', VAR_testName;
    END IF;

    -- cleanup test
    PERFORM fetchq_test_clean();

    passed = TRUE;
END; $$
LANGUAGE plpgsql;
