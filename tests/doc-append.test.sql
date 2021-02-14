
-- It should append a document and returns its subject
CREATE OR REPLACE FUNCTION fetchq_test.doc_append_01() RETURNS void AS $$
DECLARE
    VAR_r RECORD;
BEGIN
    -- initialize test
    PERFORM fetchq.queue_create('foo');

    -- should be able to queue a document with future schedule
    SELECT * INTO VAR_r FROM fetchq.doc_append('foo', '{"a":1}', 0, 0);
    PERFORM fetchq_test.expect_notNull(VAR_r.subject, 'failed append #1');

    -- should be able to queue documents with different ids
    SELECT * INTO VAR_r FROM fetchq.doc_append('foo', '{"a":2}', 0, 0);
    PERFORM fetchq_test.expect_notNull(VAR_r.subject, 'failed append #2');

    -- counters should make sense
    PERFORM fetchq.mnt();
    PERFORM fetchq.metric_log_pack();
    SELECT * INTO VAR_r FROM fetchq.metric_get('foo', 'pnd');
    PERFORM fetchq_test.expect_equalInt(VAR_r.current_value, 2, 'failed to cound pending documents after appending');
END; $$
LANGUAGE plpgsql;

-- It should be able to append many documents without collisions
CREATE OR REPLACE FUNCTION fetchq_test.doc_append_02() RETURNS void AS $$
DECLARE
    VAR_testName VARCHAR = 'SHOULD BE ABLE TO APPEND MANY DOCUMENTS';
	VAR_subject1 VARCHAR;
	VAR_subject2 VARCHAR;
    VAR_r RECORD;
    VAR_i INTEGER;
    VAR_expected INTEGER = 5;
    VAR_appended INTEGER = 0;
BEGIN
    PERFORM fetchq.queue_create('foo');

    FOR VAR_i IN 1..VAR_expected LOOP
        SELECT * INTO VAR_r FROM fetchq.doc_append('foo', '{"a":1}', 0, VAR_i);
        -- RAISE NOTICE 'uuid % (%/%)', VAR_r.subject, VAR_i, VAR_expected;
        IF VAR_r.subject IS NOT NULL THEN
            VAR_appended = VAR_appended + 1;
        END IF;
    END LoOP;

    -- should be able to queue documents with different ids
    PERFORM fetchq_test.expect_equalInt(VAR_appended, VAR_expected, 'failed');
END; $$
LANGUAGE plpgsql;


-- It should append using the simplified form
CREATE OR REPLACE FUNCTION fetchq_test.doc_append_03() RETURNS void AS $$
DECLARE
    VAR_r RECORD;
BEGIN
    PERFORM fetchq.queue_create('foo');

    SELECT * INTO VAR_r FROM fetchq.doc_append('foo', '{"a":1}');
    PERFORM fetchq_test.expect_notNull(VAR_r.subject, 'failed');
END; $$
LANGUAGE plpgsql;

-- it should NOT append a non existing queue
CREATE OR REPLACE FUNCTION fetchq_test.doc_append_04() RETURNS void AS $$
DECLARE
	VAR_subject1 VARCHAR;
	VAR_subject2 VARCHAR;
    VAR_r RECORD;
    VAR_i INTEGER;
    VAR_expected INTEGER = 25;
    VAR_appended INTEGER = 0;
BEGIN
    SELECT * INTO VAR_r FROM fetchq.doc_append('foo', '{"a":1}');
    PERFORM fetchq_test.expect_null(VAR_r.subject, 'Oh, snap! It should have returned NULL');
END; $$
LANGUAGE plpgsql;
