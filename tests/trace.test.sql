-- declare test case
CREATE OR REPLACE FUNCTION fetchq_test.fetchq_test__trace_01(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'IT SHOULD TRACE SHIT';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test.fetchq_test_init();
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

    -- prepare some queues
    PERFORM fetchq.queue_create('q1');
    PERFORM fetchq.queue_create('q2');
    PERFORM fetchq.queue_create('q3');
    PERFORM fetchq.queue_create('a1');
    PERFORM fetchq.queue_create('a2');

    -- push documents witht he same subject so to be traceable
    PERFORM fetchq.doc_push('q1', 'd1', 0, 0, NOW() - INTERVAL '1ms', '{"a":1}');
    SELECT * INTO VAR_r from fetchq.doc_pick('q1', 0, 1, '2s');
    PERFORM fetchq.log_error('q1', VAR_r.subject, 'just a log', '{}');
    PERFORM fetchq.doc_push('q2', VAR_r.subject, 0, 0, NOW() - INTERVAL '1ms', VAR_r.payload);
    SELECT * INTO VAR_r from fetchq.doc_pick('q2', 0, 1, '2s');
    PERFORM fetchq.doc_complete('q2', VAR_r.subject);
    PERFORM fetchq.doc_push('q3', VAR_r.subject, 0, 0, NOW() - INTERVAL '1ms', VAR_r.payload);
    SELECT * INTO VAR_r from fetchq.doc_pick('q3', 0, 1, '2s');
    PERFORM fetchq.doc_reject('q3', VAR_r.subject, 'error message', VAR_r.payload, 'refId');

    SELECT * INTO VAR_r FROM fetchq.trace('d1');
    -- RAISE NOTICE '%', VAR_r;
    -- RAISE EXCEPTION '##################################################################';


    passed = TRUE;
END; $$
LANGUAGE plpgsql;