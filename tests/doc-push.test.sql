

CREATE OR REPLACE FUNCTION fetchq_test.doc_push_01() RETURNS void AS $$
DECLARE
    VAR_testName VARCHAR = 'SHOULD BE ABLE TO QUEUE A SINGLE DOCUMENT WITH FUTURE SCHEDULE';
	VAR_queuedDocs INTEGER;
    VAR_r RECORD;
BEGIN
    
    -- initialize test

    PERFORM fetchq.queue_create('foo');

    -- should be able to queue a document with future schedule
    SELECT * INTO VAR_queuedDocs FROM fetchq.doc_push('foo', 'a1', 0, 0, NOW() + INTERVAL '1m', '{}');
    IF VAR_queuedDocs <> 1 THEN
        RAISE EXCEPTION 'failed - %', VAR_testName;
    END IF;

    SELECT * INTO VAR_r FROM fetchq_data.foo__docs WHERE subject = 'a1';
    IF VAR_r.status <> 0 THEN
        RAISE EXCEPTION 'failed - %(Wrong status was computed for the document)', VAR_testName;
    END IF;

    -- checkout logs
    PERFORM fetchq.metric_log_pack();
    SELECT * INTO VAR_r FROM fetchq.metric_get('foo', 'pln');
    IF VAR_r.current_value <> 1 THEN
        RAISE EXCEPTION 'failed - %(Wrong planned documents count)', VAR_testName;
    END IF;
END; $$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION fetchq_test.doc_push_02() RETURNS void AS $$
DECLARE
    VAR_testName VARCHAR = 'SHOULD BE ABLE TO QUEUE A SINGLE DOCUMENT WITH PAST SCHEDULE';
	VAR_queuedDocs INTEGER;
    VAR_r RECORD;
BEGIN

    -- initialize test

    PERFORM fetchq.queue_create('foo');
    PERFORM fetchq.queue_enable_notify('foo');

    -- should be able to queue a document with past schedule
    SELECT * INTO VAR_queuedDocs FROM fetchq.doc_push('foo', 'a100', 0, 0, NOW() - INTERVAL '1m', '{}');
    IF VAR_queuedDocs <> 1 THEN
        RAISE EXCEPTION 'failed - %(expected: 1, received: %)', VAR_testName, VAR_queuedDocs;
    END IF;

    SELECT * INTO VAR_r FROM fetchq_data.foo__docs WHERE subject = 'a1';
    IF VAR_r.status <> 1 THEN
        RAISE EXCEPTION 'failed - %(Wrong status was computed for the document)', VAR_testName;
    END IF;

    -- checkout logs
    PERFORM fetchq.metric_log_pack();
    SELECT * INTO VAR_r FROM fetchq.metric_get('foo', 'pnd');
    IF VAR_r.current_value <> 1 THEN
        RAISE EXCEPTION 'failed - %(Wrong planned documents count)', VAR_testName;
    END IF;
END; $$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fetchq_test.doc_push_03() RETURNS void AS $$
DECLARE
    VAR_testName VARCHAR = 'SHOULD BE ABLE TO QUEUE MULTIPLE DOCUMENTS';
	VAR_queuedDocs INTEGER;
    VAR_r RECORD;
BEGIN

    -- initialize test

    PERFORM fetchq.queue_create('foo');
    PERFORM fetchq.queue_enable_notify('foo');

    -- SELECT * INTO VAR_queuedDocs FROM fetchq.doc_push( 'foo', 0, NOW(), '( ''a1'', 0, ''{"a":1}'', {DATA}),(''a2'', 1, ''{"a":2}'', {DATA} )');
    -- IF VAR_queuedDocs <> 2 THEN
    --     RAISE EXCEPTION 'failed - %', VAR_testName;
    -- END IF;

    -- -- checkout logs
    -- PERFORM fetchq.metric_log_pack();
    -- SELECT * INTO VAR_r FROM fetchq.metric_get('foo', 'pnd');
    -- IF VAR_r.current_value <> 2 THEN
    --     RAISE EXCEPTION 'failed - %(Wrong pending documents count when adding multiple documents)', VAR_testName;
    -- END IF;
END; $$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fetchq_test.doc_push_04() RETURNS void AS $$
DECLARE
	VAR_queuedDocs INTEGER;
    VAR_r RECORD;
BEGIN

    -- initialize test
    PERFORM fetchq.queue_create('foo');
    PERFORM fetchq.doc_push('foo', 'd1');

    PERFORM fetchq.mnt();
    PERFORM fetchq.metric_log_pack();

    SELECT * INTO VAR_r FROM fetchq.metric_get('foo', 'pnd');
    PERFORM fetchq_test.expect_equalInt(VAR_r.current_value, 1, 'should push a document');
END; $$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fetchq_test.doc_push_05() RETURNS void AS $$
DECLARE
	VAR_queuedDocs INTEGER;
    VAR_r RECORD;
BEGIN
    -- initialize test
    PERFORM fetchq.queue_create('foo');
    PERFORM fetchq.doc_push('foo', 'd1', '{"a": 1}');

    PERFORM fetchq.mnt();
    PERFORM fetchq.metric_log_pack();

    SELECT * INTO VAR_r FROM fetchq.metric_get('foo', 'pnd');
    PERFORM fetchq_test.expect_equalInt(VAR_r.current_value, 1, 'should push a document');
END; $$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fetchq_test.doc_push_06() RETURNS void AS $$
DECLARE
	VAR_queuedDocs INTEGER;
    VAR_r RECORD;
BEGIN

    -- initialize test
    PERFORM fetchq.queue_create('foo');
    PERFORM fetchq.doc_push('foo', 'd1', '{"a":2}', NOW() - INTERVAL '5m');

    PERFORM fetchq.mnt();
    PERFORM fetchq.metric_log_pack();

    SELECT * INTO VAR_r FROM fetchq.metric_get('foo', 'pnd');
    PERFORM fetchq_test.expect_equalInt(VAR_r.current_value, 1, 'should push a document');
    
END; $$
LANGUAGE plpgsql;
