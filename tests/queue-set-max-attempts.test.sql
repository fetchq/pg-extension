
CREATE OR REPLACE FUNCTION fetchq_test__queue_set_max_attempts_01 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'COULD NOT CHANGE MAX ATTEMPTS';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();
    PERFORM fetchq_queue_create('foo');

    -- perform the operation
    SELECT * INTO VAR_r FROM fetchq_queue_set_max_attempts('foo', 1);

    IF VAR_r.affected_rows <> 1 THEN
        RAISE EXCEPTION 'failed - % (affected_rows, expected "1", got "%")', VAR_testName, VAR_r.affected_rows;
    END IF;

    -- test in the table
    SELECT * INTO VAR_r from fetchq_sys_queues
    WHERE name = 'foo' AND max_attempts = 1;
    IF VAR_r.id IS NULL THEN
        RAISE EXCEPTION 'failed - %', VAR_testName;
    END IF;

    -- cleanup
    PERFORM fetchq_test_clean();

    passed = TRUE;
END; $$
LANGUAGE plpgsql;
