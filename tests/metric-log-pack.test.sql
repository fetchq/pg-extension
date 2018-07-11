
CREATE OR REPLACE FUNCTION fetchq_test__metric_log_pack_01 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'SHOULD PACK WRITES';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();

    -- set some basic metrics
    PERFORM fetchq_metric_log_set('foo', 'cnt', 10);
    PERFORM fetchq_metric_log_increment('foo', 'cnt', 5);
    PERFORM fetchq_metric_log_decrement('foo', 'cnt', 2);

    -- fake some future metrics
    INSERT INTO fetchq_sys_metrics_writes
    (created_at, queue, metric, increment, reset)
    VALUES
    (NOW() + INTERVAL '1s', 'foo', 'cnt', 1, null);
    

    -- run maintenance
    PERFORM fetchq_mnt_run_all(100);
    SELECT * INTO VAR_r FROM fetchq_metric_log_pack();
    IF VAR_r.affected_rows <> 3 THEN
        RAISE EXCEPTION 'failed affected rows - % (count, expected 2, received %)', VAR_testName, VAR_r.affected_rows;
    END IF;

    SELECT * INTO VAR_r FROM fetchq_metric_get('foo', 'cnt');
    IF VAR_r.current_value <> 13 THEN
        RAISE EXCEPTION 'failed value - % (count, expected 13, received %)', VAR_testName, VAR_r.current_value;
    END IF;
    
    -- cleanup
    PERFORM fetchq_test_clean();
    passed = TRUE;
END; $$
LANGUAGE plpgsql;

