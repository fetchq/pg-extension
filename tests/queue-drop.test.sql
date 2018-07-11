
CREATE OR REPLACE FUNCTION fetchq_test__queue_drop_01 (
    OUT passed BOOLEAN
) AS $$
DECLARE
	VAR_numDocs INTEGER;
    VAR_r RECORD;
BEGIN
    -- initialize test
    PERFORM fetchq_test_init();

    -- create & drop the queue
    PERFORM fetchq_queue_create('foo');
    PERFORM fetchq_doc_push('foo', 'a1', 0, 0, NOW() + INTERVAL '1m', '{}');
    PERFORM fetchq_metric_log_pack();
    PERFORM fetchq_doc_push('foo', 'a2', 0, 0, NOW() + INTERVAL '1m', '{}');
    SELECT * INTO VAR_r FROM fetchq_queue_drop('foo');
    IF VAR_r.was_dropped IS NOT true THEN
        RAISE EXCEPTION 'could not drop the queue';
    END IF;

    -- check queue index
    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_sys_queues WHERE name = 'foo';
    IF VAR_numDocs > 0 THEN
		RAISE EXCEPTION 'queue index was not dropped';
	END IF;

    -- check jobs table
    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_sys_jobs WHERE queue = 'foo';
    IF VAR_numDocs > 0 THEN
		RAISE EXCEPTION 'queue jobs were not dropped';
	END IF;

    -- check logs writes
    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_sys_metrics_writes
    WHERE queue = 'foo';
    IF VAR_numDocs > 0 THEN
		RAISE EXCEPTION 'queue metrics writes were not dropped';
	END IF;

    -- check logs
    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_sys_metrics
    WHERE queue = 'foo';
    IF VAR_numDocs > 0 THEN
		RAISE EXCEPTION 'queue metrics were not dropped';
	END IF;


    -- cleanup test
    PERFORM fetchq_test_clean();
    passed = TRUE;
END; $$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fetchq_test__queue_drop_02 (
    OUT passed BOOLEAN
) AS $$
DECLARE
	VAR_numDocs INTEGER;
    VAR_r1 RECORD;
    VAR_r2 RECORD;
BEGIN
    -- initialize test
    PERFORM fetchq_test_init();

    -- create & drop the queue
    SELECT * INTO VAR_r1 FROM fetchq_queue_create('foo');
    SELECT * INTO VAR_r2 FROM fetchq_queue_drop('foo');
    IF VAR_r2.was_dropped IS NOT true THEN
        RAISE EXCEPTION 'could not drop the queue';
    END IF;
    IF VAR_r2.queue_id IS NULL THEN
        RAISE EXCEPTION 'drop queue failed to return queue_id';
    END IF;
    IF VAR_r1.queue_id != VAR_r2.queue_id THEN
        RAISE EXCEPTION 'drop queue failed to return the correct queue_id';
    END IF;

    -- cleanup test
    PERFORM fetchq_test_clean();
    passed = TRUE;
END; $$
LANGUAGE plpgsql;