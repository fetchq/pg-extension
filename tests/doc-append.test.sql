
CREATE OR REPLACE FUNCTION fetchq_test.doc_append_01(
    OUT passed BOOLEAN
) 
SET client_min_messages = error
AS $$
DECLARE
    VAR_testName VARCHAR = 'SHOULD BE ABLE TO APPEND A DOCUMENT RETURNING AN ID';
	VAR_subject1 VARCHAR;
	VAR_subject2 VARCHAR;
    VAR_r RECORD;
BEGIN
    
    -- initialize test

    PERFORM fetchq.queue_create('foo');
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

    -- should be able to queue a document with future schedule
    SELECT * INTO VAR_subject1 FROM fetchq.doc_append('foo', '{"a":1}', 0, 0);
    IF VAR_subject1 IS NULL THEN
        RAISE EXCEPTION 'failed -(null value) %', VAR_testName;
    END IF;

    -- should be able to queue documents with different ids
    SELECT * INTO VAR_subject2 FROM fetchq.doc_append('foo', '{"a":2}', 0, 0);
    IF VAR_subject1 = VAR_subject2 THEN
        RAISE EXCEPTION 'failed -(identical ids) %', VAR_testName;
    END IF;

    passed = TRUE;
END; $$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fetchq_test.doc_append_02(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'SHOULD BE ABLE TO APPEND MANY DOCUMENTS';
	VAR_subject1 VARCHAR;
	VAR_subject2 VARCHAR;
    VAR_r RECORD;
    VAR_i INTEGER;
    VAR_expected INTEGER = 25;
    VAR_appended INTEGER = 0;
BEGIN
    PERFORM fetchq.queue_create('foo');

    FOR VAR_i IN 1..VAR_expected LOOP
        SELECT * INTO VAR_subject1 FROM fetchq.doc_append('foo', '{"a":1}', 0, VAR_i);
        -- RAISE NOTICE 'uuid % (%/%)', VAR_subject1, VAR_i, VAR_expected;
        IF VAR_subject1 IS NOT NULL THEN
            VAR_appended = VAR_appended + 1;
        END IF;
    END LoOP;

    -- should be able to queue documents with different ids
    IF VAR_appended != VAR_expected THEN
        RAISE EXCEPTION 'failed -(mismatch %/%) %', VAR_appended, VAR_expected, VAR_testName;
    END IF;

    passed = TRUE;
END; $$
LANGUAGE plpgsql;


-- It should append using the simplified form
CREATE OR REPLACE FUNCTION fetchq_test.doc_append_03(
    OUT passed BOOLEAN
) AS $$
DECLARE
	VAR_subject1 VARCHAR;
	VAR_subject2 VARCHAR;
    VAR_r RECORD;
    VAR_i INTEGER;
    VAR_expected INTEGER = 25;
    VAR_appended INTEGER = 0;
BEGIN
    PERFORM fetchq.queue_create('foo');

    -- should be able to queue a document with future schedule
    SELECT * INTO VAR_subject1 FROM fetchq.doc_append('foo', '{"a":1}');
    IF VAR_subject1 IS NULL THEN
        RAISE EXCEPTION 'failed - null value';
    END IF;

    passed = TRUE;
END; $$
LANGUAGE plpgsql;
