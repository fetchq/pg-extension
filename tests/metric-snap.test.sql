
CREATE OR REPLACE FUNCTION fetchq_test.metric_snap_01(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'IT SHOULD SNAPSHOT A SINGLE METRIC FOR A QUEUE';
    VAR_r RECORD;
BEGIN
    
    -- insert dummy data - queue foo
    PERFORM fetchq.queue_create('foo');
    PERFORM fetchq.doc_push('foo', 'a1', 0, 1, NOW() - INTERVAL '10s', '{}');
    PERFORM fetchq.doc_push('foo', 'a2', 0, 1, NOW() - INTERVAL '9s', '{}');
    PERFORM fetchq.doc_push('foo', 'a3', 0, 1, NOW() - INTERVAL '8s', '{}');
    PERFORM fetchq.doc_pick('foo', 0, 1, '5m');
    PERFORM fetchq.mnt_run_all(100);
    PERFORM fetchq.metric_log_pack();

    -- run tests
    SELECT * INTO VAR_r from fetchq.metric_snap('foo', 'cnt');
    IF VAR_r.success IS NULL THEN
        RAISE EXCEPTION 'failed - %(success, got null value)', VAR_testName;
    END IF;
    IF VAR_r.success != true THEN
        RAISE EXCEPTION 'failed - %(success, got false)', VAR_testName;
    END IF;


    passed = TRUE;
END; $$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION fetchq_test.metric_snap_02(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'IT SHOULD SNAPSHOT ALL METRICS FOR A QUEUE';
    VAR_r RECORD;
BEGIN
    
    -- initialize test

    
    -- insert dummy data - queue foo
    PERFORM fetchq.queue_create('foo');
    PERFORM fetchq.doc_push('foo', 'a1', 0, 1, NOW() - INTERVAL '10s', '{}');
    PERFORM fetchq.doc_push('foo', 'a2', 0, 1, NOW() - INTERVAL '9s', '{}');
    PERFORM fetchq.doc_push('foo', 'a3', 0, 1, NOW() - INTERVAL '8s', '{}');
    PERFORM fetchq.doc_pick('foo', 0, 1, '5m');
    PERFORM fetchq.mnt_run_all(100);
    PERFORM fetchq.metric_log_pack();

    -- run tests
    SELECT * INTO VAR_r from fetchq.metric_snap('foo');
    IF VAR_r.success IS NULL THEN
        RAISE EXCEPTION 'failed - %(success, got null value)', VAR_testName;
    END IF;
    IF VAR_r.success != true THEN
        RAISE EXCEPTION 'failed - %(success, got false)', VAR_testName;
    END IF;
    IF VAR_r.inserts != 6 THEN
        RAISE EXCEPTION 'failed - %(inserts, expected 6, got %)', VAR_testName, VAR_r.inserts;
    END IF;


    passed = TRUE;
END; $$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION fetchq_test.metric_snap_03(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'IT SHOULD SNAPSHOT SELECTED METRICS FOR A QUEUE';
    VAR_r RECORD;
BEGIN
    
    -- initialize test

    
    -- insert dummy data - queue foo
    PERFORM fetchq.queue_create('foo');
    PERFORM fetchq.doc_push('foo', 'a1', 0, 1, NOW() - INTERVAL '10s', '{}');
    PERFORM fetchq.doc_push('foo', 'a2', 0, 1, NOW() - INTERVAL '9s', '{}');
    PERFORM fetchq.doc_push('foo', 'a3', 0, 1, NOW() - INTERVAL '8s', '{}');
    PERFORM fetchq.doc_pick('foo', 0, 1, '5m');
    PERFORM fetchq.mnt_run_all(100);
    PERFORM fetchq.metric_log_pack();

    -- run tests
    SELECT * INTO VAR_r from fetchq.metric_snap('foo', '[ "cnt", "act" ]'::jsonb);
    IF VAR_r.success IS NULL THEN
        RAISE EXCEPTION 'failed - %(success, got null value)', VAR_testName;
    END IF;
    IF VAR_r.success != true THEN
        RAISE EXCEPTION 'failed - %(success, got false)', VAR_testName;
    END IF;
    IF VAR_r.inserts != 2 THEN
        RAISE EXCEPTION 'failed - %(inserts, expected 2, got %)', VAR_testName, VAR_r.inserts;
    END IF;


    passed = TRUE;
END; $$
LANGUAGE plpgsql;

