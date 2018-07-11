
CREATE OR REPLACE FUNCTION fetchq_test__queue_drop_version_01 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'COULD NOT DROP OLD VERSION';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();
    PERFORM fetchq_queue_create('foo');

    -- perform the operation
    PERFORM fetchq_queue_set_current_version('foo', 1);
    SELECT * INTO VAR_r FROM fetchq_queue_drop_version('foo', 0);

    IF VAR_r.was_dropped <> true THEN
        RAISE EXCEPTION 'failed - %', VAR_testName;
    END IF;


    -- cleanup
    PERFORM fetchq_test_clean();

    passed = TRUE;
END; $$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fetchq_test__queue_drop_version_02 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'DID NOT THROW WHEN TRYING TO DROP CURRENT VERSION';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();
    PERFORM fetchq_queue_create('foo');

    -- perform the operation
    SELECT * INTO VAR_r FROM fetchq_queue_drop_version('foo', 0);

    IF VAR_r.was_dropped <> false THEN
        RAISE EXCEPTION 'failed - %', VAR_testName;
    END IF;


    -- cleanup
    PERFORM fetchq_test_clean();

    passed = TRUE;
END; $$
LANGUAGE plpgsql;


