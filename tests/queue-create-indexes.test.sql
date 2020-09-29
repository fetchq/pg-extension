
CREATE OR REPLACE FUNCTION fetchq_test.fetchq_test__queue_create_indexes_01(
    OUT passed BOOLEAN
) AS $$
DECLARE
	VAR_numDocs INTEGER;
    VAR_r RECORD;
BEGIN
    -- initialize test
    PERFORM fetchq_test.fetchq_test_init();
    PERFORM fetchq_catalog.fetchq_queue_create('foo');
    PERFORM fetchq_queue_drop_indexes('foo');

    SELECT count(*) as total INTO VAR_r FROM pg_indexes WHERE schemaname = 'fetchq_catalog' AND tablename = 'fetchq__foo__documents';
    IF VAR_r.total != 1 THEN
        RAISE EXCEPTION 'failed -(expected: 1, got: %)', VAR_r.total;
    END IF;

    PERFORM fetchq_catalog.fetchq_queue_create_indexes('foo');

    SELECT count(*) as total INTO VAR_r FROM pg_indexes WHERE schemaname = 'fetchq_catalog' AND tablename = 'fetchq__foo__documents';
    IF VAR_r.total != 6 THEN
        RAISE EXCEPTION 'failed -(expected: 6, got: %)', VAR_r.total;
    END IF;

    -- cleanup test
    PERFORM fetchq_test.fetchq_test_clean();

    passed = TRUE;
END; $$
LANGUAGE plpgsql;

