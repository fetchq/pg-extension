

DROP FUNCTION IF EXISTS fetchq_create_drop_queue_test();
CREATE OR REPLACE FUNCTION fetchq_create_drop_queue_test (
    OUT passed BOOLEAN
) AS $$
DECLARE
	VAR_numDocs INTEGER;
BEGIN
    CREATE EXTENSION fetchq;
    PERFORM fetchq_create_queue('foo');

    -- check basic tables
    PERFORM * FROM fetchq__foo__documents;
    PERFORM * FROM fetchq__foo__metrics;
    PERFORM * FROM fetchq__foo__errors;

    -- check jobs table
    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_sys_jobs WHERE subject = 'foo';
    IF VAR_numDocs < 4 THEN
		RAISE EXCEPTION 'wrong expectation';
	END IF;

    PERFORM fetchq_drop_queue('foo');
    DROP EXTENSION fetchq;

    passed = TRUE;
END; $$
LANGUAGE plpgsql;

select * from fetchq_create_drop_queue_test();
