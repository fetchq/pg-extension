
CREATE OR REPLACE FUNCTION fetchq_test__queue_create_01 (
    OUT passed BOOLEAN
) AS $$
DECLARE
	VAR_numDocs INTEGER;
    VAR_r RECORD;
BEGIN
    -- initialize test
    PERFORM fetchq_test_init();

    -- create the queue
    SELECT * INTO VAR_r FROM fetchq_queue_create('foo');
    IF VAR_r.was_created IS NOT true THEN
        RAISE EXCEPTION 'could not create the queue';
    END IF;

    -- check basic tables
    PERFORM * FROM fetchq__foo__documents;
    PERFORM * FROM fetchq__foo__metrics;
    PERFORM * FROM fetchq__foo__errors;

    -- check jobs table
    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_sys_jobs WHERE queue = 'foo';
    IF VAR_numDocs < 4 THEN
		RAISE EXCEPTION 'it seems there are not enough maintenance jobs';
	END IF;

    -- cleanup test
    PERFORM fetchq_test_clean();

    passed = TRUE;
END; $$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fetchq_test__queue_create_02 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'QUEUE NAME LENGTH SHOULD NOT EXCEED 40';
	VAR_numDocs INTEGER;
    VAR_r RECORD;
BEGIN
    -- initialize test
    PERFORM fetchq_test_init();

    -- create the queue (41 characters should not create the queue)
    SELECT * INTO VAR_r FROM fetchq_queue_create('f1234567891234567891234567899999999999999');
    IF VAR_r.was_created IS NOT false THEN
        RAISE EXCEPTION 'failed - %', VAR_testName;
    END IF;

    -- cleanup test
    PERFORM fetchq_test_clean();
    passed = TRUE;
END; $$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fetchq_test__queue_create_03 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'SHOULD CREATE A QUEUE OF 40 characters length';
	VAR_numDocs INTEGER;
    VAR_r RECORD;
BEGIN
    -- initialize test
    PERFORM fetchq_test_init();

    -- create the queue (41 characters should not create the queue)
    SELECT * INTO VAR_r FROM fetchq_queue_create('f12345678912345678912345678999999999999a');
    IF VAR_r.was_created IS NOT true THEN
        RAISE EXCEPTION 'failed - %', VAR_testName;
    END IF;

    -- cleanup test
    PERFORM fetchq_test_clean();
    passed = TRUE;
END; $$
LANGUAGE plpgsql;
