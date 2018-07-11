

CREATE OR REPLACE FUNCTION fetchq_test__log_error_01 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'COULD NOT LOG AN ERROR';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();
    PERFORM fetchq_queue_create('foo');

    -- insert dummy data
    PERFORM fetchq_log_error('foo', 'a1', 'some error', '{"a":1}');

    -- get first document
    SELECT * INTO VAR_r from fetchq__foo__errors WHERE subject = 'a1';
    IF VAR_r.subject IS NULL THEN
        RAISE EXCEPTION 'failed - %', VAR_testName;
    END IF;

    -- cleanup
    PERFORM fetchq_test_clean();

    passed = TRUE;
END; $$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fetchq_test__log_error_02 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'COULD NOT LOG AN ERROR WITH PROCESS ID';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();
    PERFORM fetchq_queue_create('foo');

    -- insert dummy data
    PERFORM fetchq_log_error('foo', 'a1', 'some error', '{"a":1}', 'ax22');

    -- get first document
    SELECT * INTO VAR_r from fetchq__foo__errors WHERE ref_id = 'ax22';
    IF VAR_r.ref_id IS NULL THEN
        RAISE EXCEPTION 'failed - %', VAR_testName;
    END IF;

    -- cleanup
    PERFORM fetchq_test_clean();

    passed = TRUE;
END; $$
LANGUAGE plpgsql;
