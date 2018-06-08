
-- declare test case
DROP FUNCTION IF EXISTS fetchq_test__create_queue();
CREATE OR REPLACE FUNCTION fetchq_test__create_queue (
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
    SELECT * INTO VAR_r FROM fetchq_create_queue('foo');
    IF VAR_r.was_created IS NOT true THEN
        RAISE EXCEPTION 'could not create the queue';
    END IF;

    -- check basic tables
    PERFORM * FROM fetchq__foo__documents;
    PERFORM * FROM fetchq__foo__metrics;
    PERFORM * FROM fetchq__foo__errors;

    -- check jobs table
    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_sys_jobs WHERE subject = 'foo';
    IF VAR_numDocs < 4 THEN
		RAISE EXCEPTION 'wrong expectation';
	END IF;

    passed = TRUE;
END; $$
LANGUAGE plpgsql;

-- run test & cleanup
SELECT * FROM fetchq_test__create_queue();
DROP FUNCTION IF EXISTS fetchq_test__create_queue();
