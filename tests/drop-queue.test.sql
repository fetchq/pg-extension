
-- declare test case
DROP FUNCTION IF EXISTS fetchq_test__drop_queue();
CREATE OR REPLACE FUNCTION fetchq_test__drop_queue (
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

    -- create & drop the queue
    PERFORM * FROM fetchq_create_queue('foo');
    SELECT * INTO VAR_r FROM fetchq_drop_queue('foo');
    IF VAR_r.was_dropped IS NOT true THEN
        RAISE EXCEPTION 'could not drop the queue';
    END IF;


    -- check queue index
    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_sys_queues WHERE name = 'foo';
    IF VAR_numDocs > 0 THEN
		RAISE EXCEPTION 'queue index was not dropped';
	END IF;

    -- check jobs table
    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_sys_jobs WHERE subject = 'foo';
    IF VAR_numDocs > 0 THEN
		RAISE EXCEPTION 'queue jobs were not dropped';
	END IF;

    passed = TRUE;
END; $$
LANGUAGE plpgsql;

-- run test & cleanup
SELECT * FROM fetchq_test__drop_queue();
DROP FUNCTION IF EXISTS fetchq_test__drop_queue();
