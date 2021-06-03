

CREATE OR REPLACE FUNCTION fetchq_test.doc_reschedule_01(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'IT SHOULD RESCHEDULE';
    VAR_r RECORD;
BEGIN
    
    -- initialize test

    PERFORM fetchq.queue_create('foo');

    -- insert dummy data
    PERFORM fetchq.doc_push('foo', 'a1', 0, 1, NOW() - INTERVAL '1s', '{}');
    PERFORM fetchq.doc_pick('foo', 0, 2, '5m');

    -- perform reschedule
    PERFORM fetchq.doc_reschedule('foo', 'a1', NOW() + INTERVAL '1y');

    -- get first document
    SELECT * INTO VAR_r from fetchq_data.foo__docs WHERE subject = 'a1';
    IF VAR_r.iterations IS NULL THEN
        RAISE EXCEPTION 'failed - %(unespected number of iterations)', VAR_testName;
    END IF;



    passed = TRUE;
END; $$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION fetchq_test.doc_reschedule_02(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'IT SHOULD RESCHEDULE WITH PAYLOAD';
    VAR_r RECORD;
BEGIN
    
    -- initialize test

    PERFORM fetchq.queue_create('foo');

    -- insert dummy data
    PERFORM fetchq.doc_push('foo', 'a1', 0, 1, NOW() - INTERVAL '1s', '{}');
    PERFORM fetchq.doc_pick('foo', 0, 2, '5m');

    -- perform reschedule
    PERFORM fetchq.doc_reschedule('foo', 'a1', NOW() + INTERVAL '1y', '{"a":1}');

    -- get first document
    SELECT * INTO VAR_r from fetchq_data.foo__docs 
    WHERE subject = 'a1'
    AND payload @> '{"a": 1}';

    IF VAR_r.iterations IS NULL THEN
        RAISE EXCEPTION 'failed - %(unespected number of iterations)', VAR_testName;
    END IF;



    passed = TRUE;
END; $$
LANGUAGE plpgsql;



-- PERFORM fetchq_test.__run('doc_reschedule_03', 'It should reschedule a document as pending');
CREATE OR REPLACE FUNCTION fetchq_test.doc_reschedule_03(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq.queue_create('foo');

    -- insert dummy data
    PERFORM fetchq.doc_push('foo', 'a1', 0, 0, NOW() - INTERVAL '1s', '{}');
    PERFORM fetchq.doc_pick('foo', 0, 2, '5m');

    -- Test a reschedule with a date in the past
    -- the document should be up for an immediate re-schedule.
    PERFORM fetchq.doc_reschedule('foo', 'a1', NOW() - INTERVAL '1ms', '{"a":1}');
    SELECT * INTO VAR_r FROM fetchq.doc_pick('foo', 0, 1, '5m');
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Failed to pick a document that was rescheduled in the past - with json';
    END IF;

    -- Duplicate the same test but without the JSON modification to the payload
    PERFORM fetchq.doc_reschedule('foo', 'a1', NOW() - INTERVAL '1ms');
    SELECT * INTO VAR_r FROM fetchq.doc_pick('foo', 0, 1, '5m');
    RAISE NOTICE '%', VAR_r;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Failed to pick a document that was rescheduled in the past - without json';
    END IF;

    -- Test a reschedule with a date exactly on NOW()
    PERFORM fetchq.doc_reschedule('foo', 'a1', NOW(), '{"a":2}');
    SELECT * INTO VAR_r FROM fetchq.doc_pick('foo', 0, 1, '5m');
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Failed to pick document that was rescheduled NOW - with json';
    END IF;
    
    -- Duplicate the same test but without the JSON modification to the payload
    PERFORM fetchq.doc_reschedule('foo', 'a1', NOW());
    SELECT * INTO VAR_r FROM fetchq.doc_pick('foo', 0, 1, '5m');
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Failed to pick document that was rescheduled NOW - without json';
    END IF;

    -- Test a reschedule with a date in the future
    PERFORM fetchq.doc_reschedule('foo', 'a1', NOW() + INTERVAL '1ms', '{"a":3}');
    SELECT * INTO VAR_r FROM fetchq.doc_pick('foo', 0, 1, '5m');
    IF VAR_r.subject = 'foo' THEN
        RAISE EXCEPTION 'Failed to reschedule a document in the future';
    END IF;

    passed = TRUE;
END; $$
LANGUAGE plpgsql;