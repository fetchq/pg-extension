

CREATE OR REPLACE FUNCTION fetchq_test.log_error_01(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'COULD NOT LOG AN ERROR';
    VAR_r RECORD;
BEGIN
    
    -- initialize test

    PERFORM fetchq.queue_create('foo');

    -- insert dummy data
    PERFORM fetchq.log_error('foo', 'a1', 'some error', '{"a":1}');

    -- get first document
    SELECT * INTO VAR_r from fetchq_data.foo__logs WHERE subject = 'a1';
    IF VAR_r.subject IS NULL THEN
        RAISE EXCEPTION 'failed - %', VAR_testName;
    END IF;



    passed = TRUE;
END; $$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fetchq_test.log_error_02(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'COULD NOT LOG AN ERROR WITH PROCESS ID';
    VAR_r RECORD;
BEGIN
    
    -- initialize test

    PERFORM fetchq.queue_create('foo');

    -- insert dummy data
    PERFORM fetchq.log_error('foo', 'a1', 'some error', '{"a":1}', 'ax22');

    -- get first document
    SELECT * INTO VAR_r from fetchq_data.foo__logs WHERE ref_id = 'ax22';
    IF VAR_r.ref_id IS NULL THEN
        RAISE EXCEPTION 'failed - %', VAR_testName;
    END IF;



    passed = TRUE;
END; $$
LANGUAGE plpgsql;
