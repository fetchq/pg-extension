
CREATE OR REPLACE FUNCTION fetchq_test.fetchq_test__queue_status_01(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'IT SHOULD RETRIEVE QUEUES STATUS';
	VAR_numQueues INTEGER;
    VAR_r RECORD;
BEGIN
    -- initialize test
    PERFORM fetchq_test.fetchq_test_init();

    -- create & drop the queue
    PERFORM fetchq_catalog.fetchq_queue_create('foo');
    PERFORM fetchq_catalog.fetchq_queue_create('faa');
    
    SELECT COUNT(*) INTO VAR_numQueues FROM fetchq_queue_status();
    IF VAR_numQueues != 2 THEN
        RAISE EXCEPTION 'failed - %(count, got %)', VAR_testName, VAR_numQueues;
    END IF;

    SELECT COUNT(*) INTO VAR_numQueues FROM fetchq_queue_status('foo');
    IF VAR_numQueues != 1 THEN
        RAISE EXCEPTION 'failed - %(count, got %)', VAR_testName, VAR_numQueues;
    END IF;

    SELECT * INTO VAR_r FROM fetchq_queue_status('foo');
    IF VAR_r.is_active IS NOT TRUE THEN
        RAISE EXCEPTION 'failed - %(is_active, got %)', VAR_testName, VAR_r.is_active;
    END IF;

    -- cleanup test
    PERFORM fetchq_test.fetchq_test_clean();
    passed = TRUE;
END; $$
LANGUAGE plpgsql;
