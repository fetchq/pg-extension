

CREATE OR REPLACE FUNCTION fetchq_test__metric_get_01 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_r RECORD;
BEGIN

    -- initialize test
    PERFORM fetchq_test_init();
    PERFORM fetchq_queue_create('foo');

    -- test set counters
    PERFORM fetchq_metric_set('a', 'b', 4);
    PERFORM fetchq_metric_set('a', 'b', 5);
    PERFORM fetchq_metric_increment('a', 'b', 5);
    PERFORM fetchq_metric_increment('a', 'b', -3);

    -- test log counters
    PERFORM fetchq_metric_log_increment('a', 'b', 10);
    PERFORM fetchq_metric_log_decrement('a', 'b', 5);
    PERFORM fetchq_metric_log_pack();

    SELECT * INTO VAR_r from fetchq_metric_get('a', 'b');
    IF VAR_r.current_value <> 12 THEN
        RAISE EXCEPTION 'Wrong metric computation';
    END IF;

    -- test reset on logs
    PERFORM fetchq_metric_log_increment('b', 'c', 10);
    PERFORM fetchq_metric_log_decrement('b', 'c', 5);
    PERFORM fetchq_metric_log_set('b', 'c', 99);
    PERFORM fetchq_metric_log_pack();

    SELECT * INTO VAR_r from fetchq_metric_get('b', 'c');
    IF VAR_r.current_value <> 104 THEN
        RAISE EXCEPTION 'Wrong metric computation';
    END IF;

    -- cleanup test
    PERFORM fetchq_test_clean();

    passed = TRUE;
END; $$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fetchq_test__metric_get_02 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_qA VARCHAR = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    VAR_qB VARCHAR = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    VAR_r RECORD;
BEGIN

    -- initialize test
    PERFORM fetchq_test_init();

    -- test set counters
    PERFORM fetchq_metric_set(VAR_qA, 'b', 4);
    PERFORM fetchq_metric_set(VAR_qA, 'b', 5);
    PERFORM fetchq_metric_increment(VAR_qA, 'b', 5);
    PERFORM fetchq_metric_increment(VAR_qA, 'b', -3);

    -- test log counters
    PERFORM fetchq_metric_log_increment(VAR_qA, 'b', 10);
    PERFORM fetchq_metric_log_decrement(VAR_qA, 'b', 5);
    PERFORM fetchq_metric_log_pack();

    SELECT * INTO VAR_r from fetchq_metric_get(VAR_qA, 'b');
    IF VAR_r.current_value <> 12 THEN
        RAISE EXCEPTION 'Wrong metric computation1';
    END IF;

    -- test reset on logs
    PERFORM fetchq_metric_log_increment(VAR_qB, 'c', 10);
    PERFORM fetchq_metric_log_decrement(VAR_qB, 'c', 5);
    PERFORM fetchq_metric_log_set(VAR_qB, 'c', 99);
    PERFORM fetchq_metric_log_pack();

    SELECT * INTO VAR_r from fetchq_metric_get(VAR_qB, 'c');
    IF VAR_r.current_value <> 104 THEN
        RAISE EXCEPTION 'Wrong metric computation2, %', VAR_r.current_value;
    END IF;

    -- cleanup test
    PERFORM fetchq_test_clean();

    passed = TRUE;
END; $$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fetchq_test__metric_get_03 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'COULD NOT GET ALL QUEUE METRICS';
    VAR_qA VARCHAR = 'foo';
    VAR_r RECORD;
    VAR_affectedRows INTEGER;
BEGIN

    -- initialize test
    PERFORM fetchq_test_init();

    -- set counters
    PERFORM fetchq_metric_set(VAR_qA, 'a', 2);
    PERFORM fetchq_metric_set(VAR_qA, 'b', 3);
    PERFORM fetchq_metric_increment(VAR_qA, 'c', 3);
    PERFORM fetchq_metric_increment(VAR_qA, 'd', 4);
    PERFORM fetchq_metric_log_decrement(VAR_qA, 'a', 1);
    PERFORM fetchq_metric_log_decrement(VAR_qA, 'b', 1);
    PERFORM fetchq_metric_log_decrement(VAR_qA, 'd', 5);
    PERFORM fetchq_metric_log_pack();

    -- run the test
    PERFORM fetchq_metric_get(VAR_qA);
    GET DIAGNOSTICS VAR_affectedRows := ROW_COUNT;
    
    -- test result rows
    IF VAR_affectedRows <> 4 THEN
        RAISE EXCEPTION 'failed - % (affected_rows, expected "4", got "%")', VAR_testName, VAR_affectedRows;
    END IF;

    -- test result order
    SELECT * INTO VAR_r FROM fetchq_metric_get(VAR_qA);
    IF VAR_r.metric <> 'a' THEN
        RAISE EXCEPTION 'failed - % (metric, expected "a", got "%")', VAR_testName, VAR_r.metric;
    END IF;

    -- cleanup test
    PERFORM fetchq_test_clean();
    passed = TRUE;
END; $$
LANGUAGE plpgsql;
