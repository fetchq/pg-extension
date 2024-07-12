
-- declare test case
-- DROP FUNCTION IF EXISTS fetchq_test.pick();
CREATE OR REPLACE FUNCTION fetchq_test.doc_pick_01(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'OLDER DOCUMENT SHOULD GO FIRST';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq.queue_create('foo');


    -- insert dummy data
    PERFORM fetchq.doc_push('foo', 'a1', 0, 0, NOW() - INTERVAL '1s', '{}');
    PERFORM fetchq.doc_push('foo', 'a2', 0, 0, NOW() - INTERVAL '2s', '{}');

    -- get first document
    SELECT * INTO VAR_r from fetchq.doc_pick('foo', 0, 1, '5m');
    IF VAR_r.subject IS NULL THEN
        RAISE EXCEPTION 'failed(null value) - %', VAR_testName;
    END IF;
    IF VAR_r.subject != 'a2' THEN
        RAISE EXCEPTION 'failed - %', VAR_testName;
    END IF;

    passed = TRUE;
END; $$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION fetchq_test.doc_pick_02(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'HIGER PRIORITY SHOULD GO FIRST';
    VAR_r1 RECORD;
    VAR_r RECORD;
BEGIN
    
    -- initialize test

    PERFORM fetchq.queue_create('foo');

    -- insert dummy data
    PERFORM fetchq.doc_push('foo', 'a1', 0, 1, NOW() - INTERVAL '1s', '{}');
    PERFORM fetchq.doc_push('foo', 'a2', 0, 0, NOW() - INTERVAL '1s', '{}');

    -- get first document
    SELECT * INTO VAR_r from fetchq.doc_pick('foo', 0, 1, '5m');
    IF VAR_r.subject IS NULL THEN
        RAISE EXCEPTION 'failed(null value) - %', VAR_testName;
    END IF;
    IF VAR_r.subject <> 'a1' THEN
        RAISE EXCEPTION 'failed - %', VAR_testName;
    END IF;

    passed = TRUE;
END; $$
LANGUAGE plpgsql;




CREATE OR REPLACE FUNCTION fetchq_test.doc_pick_03(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'LIMIT SHOULD BE RELIABLE';
    VAR_affectedRows INTEGER;
BEGIN
    
    -- initialize test

    PERFORM fetchq.queue_create('foo');

    -- insert dummy data
    PERFORM fetchq.doc_push('foo', 'a1', 0, 0, NOW() - INTERVAL '1s', '{}');
    PERFORM fetchq.doc_push('foo', 'a2', 0, 0, NOW() - INTERVAL '1s', '{}');
    PERFORM fetchq.doc_push('foo', 'a3', 0, 0, NOW() - INTERVAL '1s', '{}');

    -- get first document
    PERFORM fetchq.doc_pick('foo', 0, 2, '5m');
    GET DIAGNOSTICS VAR_affectedRows := ROW_COUNT;
    IF VAR_affectedRows <> 2 THEN
        RAISE EXCEPTION 'failed - %(returned % rows instead of 2)', VAR_testName, VAR_affectedRows;
    END IF;



    passed = TRUE;
END; $$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION fetchq_test.doc_pick_04(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'COUNTERS SHOULD BE UPDATED';
    VAR_affectedRows INTEGER;
    VAR_r RECORD;
BEGIN
    
    -- initialize test

    PERFORM fetchq.queue_create('foo');

    -- insert dummy data
    PERFORM fetchq.doc_push('foo', 'a1', 0, 0, NOW() - INTERVAL '1s', '{}');
    PERFORM fetchq.doc_push('foo', 'a2', 0, 0, NOW() - INTERVAL '1s', '{}');
    PERFORM fetchq.doc_push('foo', 'a3', 0, 0, NOW() - INTERVAL '1s', '{}');
    PERFORM fetchq.doc_push('foo', 'a4', 0, 0, NOW() + INTERVAL '1s', '{}');

    -- get first document
    PERFORM fetchq.doc_pick('foo', 0, 2, '5m');
    PERFORM fetchq.metric_log_pack();
    
    -- test CNT
    SELECT * INTO VAR_r FROM fetchq.metric_get('foo', 'cnt');
    IF VAR_r.current_value <> 4 THEN
        RAISE EXCEPTION 'failed - %(count, expected 4, received %)', VAR_testName, VAR_r.current_value;
    END IF;

    -- test ACT
    SELECT * INTO VAR_r FROM fetchq.metric_get('foo', 'act');
    IF VAR_r.current_value <> 2 THEN
        RAISE EXCEPTION 'failed - %(active, expected 2, received %)', VAR_testName, VAR_r.current_value;
    END IF;

    -- test PND
    SELECT * INTO VAR_r FROM fetchq.metric_get('foo', 'pnd');
    IF VAR_r.current_value <> 1 THEN
        RAISE EXCEPTION 'failed - %(pending, expected 1, received %)', VAR_testName, VAR_r.current_value;
    END IF;

    -- test PLN
    SELECT * INTO VAR_r FROM fetchq.metric_get('foo', 'pln');
    IF VAR_r.current_value <> 1 THEN
        RAISE EXCEPTION 'failed - %(pending, expected 1, received %)', VAR_testName, VAR_r.current_value;
    END IF;



    passed = TRUE;
END; $$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION fetchq_test.doc_pick_05(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'IT SHOULD PICK MULTIPLE DOCUMENTS';
    VAR_affectedRows INTEGER;
    VAR_r RECORD;
BEGIN
    
    -- initialize test

    PERFORM fetchq.queue_create('foo');

    -- insert dummy data
    PERFORM fetchq.doc_push('foo', 'a1', 0, 0, NOW() - INTERVAL '50s', '{}');
    PERFORM fetchq.doc_push('foo', 'a2', 0, 0, NOW() - INTERVAL '40s', '{}');

    -- get first document
    SELECT * INTO VAR_r FROM fetchq.doc_pick('foo', 0, 1, '5m');
    GET DIAGNOSTICS VAR_affectedRows := ROW_COUNT;
    IF VAR_r.subject IS NULL THEN
        RAISE EXCEPTION 'failed(null value) - %', VAR_testName;
    END IF;
    IF VAR_affectedRows <> 1 THEN
        RAISE EXCEPTION 'failed - %(count, expected 1, received %)', VAR_testName, VAR_affectedRows;
    END IF;
    IF VAR_r.subject <> 'a1' THEN
        RAISE EXCEPTION 'failed - %(subject, expected "a1", received %)', VAR_testName, VAR_r.subject;
    END IF;

    -- get second document
    SELECT * INTO VAR_r FROM fetchq.doc_pick('foo', 0, 1, '5m');
    GET DIAGNOSTICS VAR_affectedRows := ROW_COUNT;
    IF VAR_r.subject IS NULL THEN
        RAISE EXCEPTION 'failed(null value) - %', VAR_testName;
    END IF;
    IF VAR_affectedRows <> 1 THEN
        RAISE EXCEPTION 'failed - %(count, expected 1, received %)', VAR_testName, VAR_affectedRows;
    END IF;
    IF VAR_r.subject <> 'a2' THEN
        RAISE EXCEPTION 'failed - %(subject, expected "a2", received %)', VAR_testName, VAR_r.subject;
    END IF;


    passed = TRUE;
END; $$
LANGUAGE plpgsql;


-- It should pick a single document with a custom lock
CREATE OR REPLACE FUNCTION fetchq_test.doc_pick_06(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_affectedRows INTEGER;
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq.queue_create('foo');

    -- insert dummy data
    PERFORM fetchq.doc_push('foo', 'a1', 0, 0, NOW() - INTERVAL '50s', '{}');
    PERFORM fetchq.doc_push('foo', 'a2', 0, 0, NOW() - INTERVAL '40s', '{}');

    -- get first document
    SELECT * INTO VAR_r FROM fetchq.doc_pick('foo', '5m');
    GET DIAGNOSTICS VAR_affectedRows := ROW_COUNT;
    IF VAR_r.subject IS NULL THEN
        RAISE EXCEPTION 'null value';
    END IF;
    IF VAR_affectedRows <> 1 THEN
        RAISE EXCEPTION 'count: expected 1, received %)', VAR_affectedRows;
    END IF;
    IF VAR_r.subject <> 'a1' THEN
        RAISE EXCEPTION 'subject: expected "a1", received "%")', VAR_r.subject;
    END IF;

    -- get second document
    SELECT * INTO VAR_r FROM fetchq.doc_pick('foo', 0, 1, '5m');
    GET DIAGNOSTICS VAR_affectedRows := ROW_COUNT;
    IF VAR_r.subject IS NULL THEN
        RAISE EXCEPTION 'null value';
    END IF;
    IF VAR_affectedRows <> 1 THEN
        RAISE EXCEPTION 'count: expected 1, received %)', VAR_affectedRows;
    END IF;
    IF VAR_r.subject <> 'a2' THEN
        RAISE EXCEPTION 'subject: expected "a2", received "%")', VAR_r.subject;
    END IF;

END; $$
LANGUAGE plpgsql;

-- It should pick a single document with the default lock
CREATE OR REPLACE FUNCTION fetchq_test.doc_pick_07(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_affectedRows INTEGER;
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq.queue_create('foo');

    -- insert dummy data
    PERFORM fetchq.doc_push('foo', 'a1', 0, 0, NOW() - INTERVAL '50s', '{}');
    PERFORM fetchq.doc_push('foo', 'a2', 0, 0, NOW() - INTERVAL '40s', '{}');

    -- get first document
    SELECT * INTO VAR_r FROM fetchq.doc_pick('foo', '5m');
    GET DIAGNOSTICS VAR_affectedRows := ROW_COUNT;
    IF VAR_r.subject IS NULL THEN
        RAISE EXCEPTION 'null value';
    END IF;
    IF VAR_affectedRows <> 1 THEN
        RAISE EXCEPTION 'count: expected 1, received %)', VAR_affectedRows;
    END IF;
    IF VAR_r.subject <> 'a1' THEN
        RAISE EXCEPTION 'subject: expected "a1", received "%")', VAR_r.subject;
    END IF;

    -- get second document
    SELECT * INTO VAR_r FROM fetchq.doc_pick('foo', 0, 1, '5m');
    GET DIAGNOSTICS VAR_affectedRows := ROW_COUNT;
    IF VAR_r.subject IS NULL THEN
        RAISE EXCEPTION 'null value';
    END IF;
    IF VAR_affectedRows <> 1 THEN
        RAISE EXCEPTION 'count: expected 1, received %)', VAR_affectedRows;
    END IF;
    IF VAR_r.subject <> 'a2' THEN
        RAISE EXCEPTION 'subject: expected "a2", received "%")', VAR_r.subject;
    END IF;

END; $$
LANGUAGE plpgsql;


-- It should pick a list of documents and lock it with the default lock
CREATE OR REPLACE FUNCTION fetchq_test.doc_pick_08(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_affectedRows INTEGER;
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq.queue_create('foo');

    -- insert dummy data
    PERFORM fetchq.doc_push('foo', 'a1', 0, 0, NOW() - INTERVAL '50s', '{}');
    PERFORM fetchq.doc_push('foo', 'a2', 0, 0, NOW() - INTERVAL '40s', '{}');

    -- get first document
    PERFORM fetchq.doc_pick('foo', 2);
    GET DIAGNOSTICS VAR_affectedRows := ROW_COUNT;

    IF VAR_affectedRows <> 2 THEN
        RAISE EXCEPTION 'count: expected 2, received %', VAR_affectedRows;
    END IF;

END; $$
LANGUAGE plpgsql;