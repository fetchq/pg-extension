-- declare test case
CREATE OR REPLACE FUNCTION fetchq_test__utils_ts_retain_01 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'IT SHOULD DROP RECORDS WITH A RETENTION POLICY';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();

    CREATE TABLE test_utils_ts_retain (
        id SERIAL PRIMARY KEY,
        created_at TIMESTAMP WITH TIME ZONE
    );

    INSERT INTO test_utils_ts_retain ( created_at ) VALUES
    -- keep only 1 per minute, 2 records
    ( '2010-10-01 12:00:00' ),
    ( '2010-10-01 12:00:10' ),
    ( '2010-10-01 12:00:30' ),
    ( '2010-10-01 12:01:00' ),
    ( '2010-10-01 12:01:10' ),
    ( '2010-10-01 12:01:30' ),
    -- keep only 1 per hour, 2 records
    ( '2010-11-01 12:00:00' ),
    ( '2010-11-01 12:20:00' ),
    ( '2010-11-01 12:40:00' ),
    ( '2010-11-01 13:00:00' ),
    ( '2010-11-01 13:20:00' ),
    ( '2010-11-01 13:40:00' ),
    -- keep all
    ( '20120-11-01 13:40:00' ),
    ( '20120-11-01 13:40:01' ),
    ( '20120-11-01 13:40:02' ),
    ( '20120-11-01 13:40:03' );

    -- perform retention rules
    PERFORM fetchq_utils_ts_retain( 'test_utils_ts_retain', 'created_at', 'minute', '2010-10-01 11:00:00', '2010-10-01 13:00:00');
    PERFORM fetchq_utils_ts_retain( 'test_utils_ts_retain', 'created_at', 'hour', '2010-11-01 00:00:00', '2010-11-30 11:59:00');

    SELECT COUNT(*) AS tot INTO VAR_r FROM test_utils_ts_retain;
    IF VAR_r.tot IS NULL THEN
        RAISE EXCEPTION 'failed - (null value) %', VAR_testName;
    END IF;
    IF VAR_r.tot != 8 THEN
        RAISE EXCEPTION 'failed - (expected: 8, got: %) %', VAR_r.tot, VAR_testName;
    END IF;

    -- cleanup
    PERFORM fetchq_test_clean();
    passed = TRUE;
END; $$
LANGUAGE plpgsql;
