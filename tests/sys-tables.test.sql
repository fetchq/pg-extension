
-- declare test case
DROP FUNCTION IF EXISTS fetchq_test__sys_tables();
CREATE OR REPLACE FUNCTION fetchq_test__sys_tables (
    OUT passed BOOLEAN
) AS $$
DECLARE
	VAR_numDocs INTEGER;
    VAR_r RECORD;
BEGIN
    -- initialize test
    DROP SCHEMA public CASCADE;
    CREATE SCHEMA public;
    DROP EXTENSION IF EXISTS fetchq;
    CREATE EXTENSION fetchq;

    -- create the queue
    PERFORM * from fetchq_sys_queues;
    PERFORM * from fetchq_sys_metrics;
    PERFORM * from fetchq_sys_metrics_writes;
    PERFORM * from fetchq_sys_jobs;

    passed = TRUE;
END; $$
LANGUAGE plpgsql;

-- run test & cleanup
SELECT * FROM fetchq_test__sys_tables();
DROP FUNCTION IF EXISTS fetchq_test__sys_tables();