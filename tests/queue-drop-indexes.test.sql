-- declare test case
CREATE OR REPLACE FUNCTION fetchq_test.queue_drop_indexes_01(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'IT SHOULD DROP INDEXES FROM A QUEUE TABLE';
    VAR_r RECORD;
BEGIN
    
    -- initialize test

    PERFORM fetchq.queue_create('foo');

    -- assert normal indexes
    SELECT count(*) as total INTO VAR_r FROM pg_indexes WHERE schemaname = 'fetchq_data' AND tablename = 'foo__docs';
    IF VAR_r.total != 6 THEN
        RAISE EXCEPTION 'failed -(expected: 6, got: %)', VAR_r.total;
    END IF;

    -- assert dropping result
    SELECT * INTO VAR_r FROM fetchq.queue_drop_indexes('foo');
    IF VAR_r.was_dropped IS NOT TRUE THEN
        RAISE EXCEPTION 'failed - unexpeted response while dropping indexes';
    END IF;

    -- assert no indexes
    SELECT count(*) as total INTO VAR_r FROM pg_indexes WHERE schemaname = 'fetchq_data' AND tablename = 'foo__docs';
    IF VAR_r.total != 1 THEN
        RAISE EXCEPTION 'failed -(expected: 1, got: %)', VAR_r.total;
    END IF;


    passed = TRUE;
END; $$
LANGUAGE plpgsql;
