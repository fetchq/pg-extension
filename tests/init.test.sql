
-- declare test case
-- DROP FUNCTION IF EXISTS fetchq_test.init();
CREATE OR REPLACE FUNCTION fetchq_test.init(
    OUT passed BOOLEAN
) AS $$
DECLARE
	VAR_numDocs INTEGER;
    VAR_r RECORD;
BEGIN

    -- should be able to gracefully fail
    PERFORM fetchq.init();
    PERFORM fetchq.init();

    -- create the queue
    PERFORM * from fetchq.queues;
    PERFORM * from fetchq.metrics;
    PERFORM * from fetchq.metrics_writes;
    PERFORM * from fetchq.jobs;

    passed = TRUE;
END; $$
LANGUAGE plpgsql;

-- run test & cleanup
-- SELECT * FROM fetchq_test.init();
-- DROP FUNCTION IF EXISTS fetchq_test.init();