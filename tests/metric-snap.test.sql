
CREATE OR REPLACE FUNCTION fetchq_test__metric_snap_01 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'IT SHOULD SNAPSHOT A SINGLE METRIC FOR A QUEUE';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();
    
    -- insert dummy data - queue foo
    PERFORM fetchq_queue_create('foo');
    PERFORM fetchq_doc_push('foo', 'a1', 0, 1, NOW() - INTERVAL '10s', '{}');
    PERFORM fetchq_doc_push('foo', 'a2', 0, 1, NOW() - INTERVAL '9s', '{}');
    PERFORM fetchq_doc_push('foo', 'a3', 0, 1, NOW() - INTERVAL '8s', '{}');
    PERFORM fetchq_doc_pick('foo', 0, 1, '5m');
    PERFORM fetchq_mnt_run_all(100);
    PERFORM fetchq_metric_log_pack();

    -- run tests
    SELECT * INTO VAR_r from fetchq_metric_snap('foo', 'cnt');
    IF VAR_r.success IS NULL THEN
        RAISE EXCEPTION 'failed - % (success, got null value)', VAR_testName;
    END IF;
    IF VAR_r.success != true THEN
        RAISE EXCEPTION 'failed - % (success, got false)', VAR_testName;
    END IF;

    -- cleanup
    PERFORM fetchq_test_clean();
    passed = TRUE;
END; $$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION fetchq_test__metric_snap_02 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'IT SHOULD SNAPSHOT ALL METRICS FOR A QUEUE';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();
    
    -- insert dummy data - queue foo
    PERFORM fetchq_queue_create('foo');
    PERFORM fetchq_doc_push('foo', 'a1', 0, 1, NOW() - INTERVAL '10s', '{}');
    PERFORM fetchq_doc_push('foo', 'a2', 0, 1, NOW() - INTERVAL '9s', '{}');
    PERFORM fetchq_doc_push('foo', 'a3', 0, 1, NOW() - INTERVAL '8s', '{}');
    PERFORM fetchq_doc_pick('foo', 0, 1, '5m');
    PERFORM fetchq_mnt_run_all(100);
    PERFORM fetchq_metric_log_pack();

    -- run tests
    SELECT * INTO VAR_r from fetchq_metric_snap('foo');
    IF VAR_r.success IS NULL THEN
        RAISE EXCEPTION 'failed - % (success, got null value)', VAR_testName;
    END IF;
    IF VAR_r.success != true THEN
        RAISE EXCEPTION 'failed - % (success, got false)', VAR_testName;
    END IF;
    IF VAR_r.inserts != 10 THEN
        RAISE EXCEPTION 'failed - % (inserts, expected 10, got %)', VAR_testName, VAR_r.inserts;
    END IF;

    -- cleanup
    PERFORM fetchq_test_clean();
    passed = TRUE;
END; $$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION fetchq_test__metric_snap_03 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'IT SHOULD SNAPSHOT SELECTED METRICS FOR A QUEUE';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();
    
    -- insert dummy data - queue foo
    PERFORM fetchq_queue_create('foo');
    PERFORM fetchq_doc_push('foo', 'a1', 0, 1, NOW() - INTERVAL '10s', '{}');
    PERFORM fetchq_doc_push('foo', 'a2', 0, 1, NOW() - INTERVAL '9s', '{}');
    PERFORM fetchq_doc_push('foo', 'a3', 0, 1, NOW() - INTERVAL '8s', '{}');
    PERFORM fetchq_doc_pick('foo', 0, 1, '5m');
    PERFORM fetchq_mnt_run_all(100);
    PERFORM fetchq_metric_log_pack();

    -- run tests
    SELECT * INTO VAR_r from fetchq_metric_snap('foo', '[ "cnt", "act" ]'::jsonb);
    IF VAR_r.success IS NULL THEN
        RAISE EXCEPTION 'failed - % (success, got null value)', VAR_testName;
    END IF;
    IF VAR_r.success != true THEN
        RAISE EXCEPTION 'failed - % (success, got false)', VAR_testName;
    END IF;
    IF VAR_r.inserts != 2 THEN
        RAISE EXCEPTION 'failed - % (inserts, expected 2, got %)', VAR_testName, VAR_r.inserts;
    END IF;

    -- cleanup
    PERFORM fetchq_test_clean();
    passed = TRUE;
END; $$
LANGUAGE plpgsql;

