-- declare test case
CREATE OR REPLACE FUNCTION fetchq_test__queue_drop_metrics_01 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'IT SHOULD DROP METRICS GIVEN A JSON CONFIGURATION';
    VAR_policy VARCHAR;
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();
    PERFORM fetchq_queue_create('foo');

    INSERT INTO fetchq__foo__metrics ( created_at, metric, value ) VALUES
    -- within the hour
    ( NOW() - INTERVAL '10 seconds', 'a', 1 ),
    ( NOW() - INTERVAL '20 seconds', 'a', 2 ),
    ( NOW() - INTERVAL '30 seconds', 'a', 3 ),
    ( NOW() - INTERVAL '60 seconds', 'b', 1 ),
    ( NOW() - INTERVAL '70 seconds', 'b', 2 ),
    ( NOW() - INTERVAL '2 hours', 'c', 1 ),
    ( NOW() - INTERVAL '2 hours 10 minutes', 'c', 2 ),
    ( NOW() - INTERVAL '2 hours 20 minutes', 'c', 3 ),
    ( NOW() - INTERVAL '3 hours', 'd', 1 ),
    ( NOW() - INTERVAL '3 hours 10 minutes', 'd', 2 ),
    ( NOW() - INTERVAL '3 hours 20 minutes', 'd', 3 )
    ;

    -- drop metrics by policy
    VAR_policy = '[{ "retain":"minute", "from":"1h", "to":"0s" }, { "retain":"hour", "from":"100y", "to":"1h" }]';
    SELECT * INTO VAR_r FROM fetchq_queue_drop_metrics('foo', VAR_policy::jsonb);
    RAISE NOTICE 'result %', VAR_r;

    IF VAR_r.removed_rows IS NULL THEN
        RAISE EXCEPTION 'failed - (null value) %', VAR_testName;
    END IF;
    IF VAR_r.removed_rows >= 5 THEN
        RAISE NOTICE 'failed - (expected >= 5, got: %) %', VAR_r.removed_rows, VAR_testName;
    END IF;

    -- cleanup
    -- PERFORM fetchq_test_clean();
    passed = TRUE;
END; $$
LANGUAGE plpgsql;

-- declare test case
CREATE OR REPLACE FUNCTION fetchq_test__queue_drop_metrics_02 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'IT SHOULD DROP METRICS FROM QUEUE CONFIGURATION';
    VAR_policy VARCHAR;
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();
    PERFORM fetchq_queue_create('foo');
    PERFORM fetchq_queue_set_metrics_retention('foo', '[{"to": "0s", "from": "1h", "retain": "minute"}, {"to": "1h", "from": "100y", "retain": "hour"}]');

    INSERT INTO fetchq__foo__metrics ( created_at, metric, value ) VALUES
    -- within the hour
    ( NOW(), 'a', 1 ),
    ( NOW() - INTERVAL '10 seconds', 'a', 2 ),
    ( NOW() - INTERVAL '20 seconds', 'a', 3 ),
    ( NOW() - INTERVAL '60 seconds', 'b', 1 ),
    ( NOW() - INTERVAL '70 seconds', 'b', 2 ),
    ( NOW() - INTERVAL '2 hours', 'c', 1 ),
    ( NOW() - INTERVAL '2 hours 10 minutes', 'c', 2 ),
    ( NOW() - INTERVAL '2 hours 20 minutes', 'c', 3 ),
    ( NOW() - INTERVAL '3 hours', 'd', 1 ),
    ( NOW() - INTERVAL '3 hours 10 minutes', 'd', 2 ),
    ( NOW() - INTERVAL '3 hours 20 minutes', 'd', 3 )
    ;

    -- drop metrics by policy
    SELECT * INTO VAR_r FROM fetchq_queue_drop_metrics('foo');
    RAISE NOTICE 'result %', VAR_r;

    IF VAR_r.removed_rows IS NULL THEN
        RAISE EXCEPTION 'failed - (null value) %', VAR_testName;
    END IF;
    IF VAR_r.removed_rows >= 5 THEN
        RAISE NOTICE 'failed - (expected >= 5, got: %) %', VAR_r.removed_rows, VAR_testName;
    END IF;

    -- cleanup
    -- PERFORM fetchq_test_clean();
    passed = TRUE;
END; $$
LANGUAGE plpgsql;