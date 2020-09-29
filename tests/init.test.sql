
-- declare test case
-- DROP FUNCTION IF EXISTS fetchq_test.fetchq_test__init();
CREATE OR REPLACE FUNCTION fetchq_test.fetchq_test__init(
    OUT passed BOOLEAN
) AS $$
DECLARE
	VAR_numDocs INTEGER;
    VAR_r RECORD;
BEGIN
    -- initialize test
    PERFORM fetchq_test.fetchq_test_init();

    -- should be able to gracefully fail
    PERFORM fetchq_catalog.fetchq_init();
    PERFORM fetchq_catalog.fetchq_init();

    -- create the queue
    PERFORM * from fetchq.queues;
    PERFORM * from fetchq.metrics;
    PERFORM * from fetchq.metrics_writes;
    PERFORM * from fetchq.jobs;

    -- cleanup test
    PERFORM fetchq_test.fetchq_test_clean();

    passed = TRUE;
END; $$
LANGUAGE plpgsql;

-- run test & cleanup
-- SELECT * FROM fetchq_test.fetchq_test__init();
-- DROP FUNCTION IF EXISTS fetchq_test.fetchq_test__init();