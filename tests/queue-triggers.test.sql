
CREATE OR REPLACE FUNCTION fetchq_test.queue_triggers_01(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'IT SHOULD ACTIVATE TRIGGERS';
	VAR_numDocs INTEGER;
    VAR_r RECORD;
BEGIN
    -- initialize test
    PERFORM fetchq.queue_create('foo');
    PERFORM fetchq.queue_enable_notify('foo');

    PERFORM fetchq.doc_push('foo', 'doc1', 0, 0, NOW() - INTERVAL '1s', '{"foo": 123}');

    SELECT * INTO VAR_r FROM fetchq.doc_pick('foo', 0, 1, '1ms');
    IF VAR_r.subject IS NULL THEN
        RAISE EXCEPTION 'failed pick document (null value)';
    END IF;

    -- create & drop the queue
    PERFORM fetchq.doc_push('foo', 'a1', 0, 0, NOW() + INTERVAL '1m', '{}');
    PERFORM fetchq.doc_push('foo', 'a2', 0, 0, NOW() + INTERVAL '1m', '{}');
    PERFORM fetchq.doc_push('foo', 'a3', 0, 0, NOW() + INTERVAL '1m', '{}');
    PERFORM fetchq.doc_push('foo', 'a4', 1, 0, NOW() + INTERVAL '1m', '{}');
    PERFORM fetchq.doc_push('foo', 'a5', 1, 0, NOW() + INTERVAL '1m', '{}');
    PERFORM fetchq.doc_push('foo', 'a6', 1, 0, NOW() + INTERVAL '1m', '{}');
    
    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq.queue_top('foo', 0, 3, 0);
    IF VAR_numDocs != 3 THEN
        RAISE EXCEPTION 'failed - %(count, got %)', VAR_testName, VAR_numDocs;
    END IF;

    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq.queue_top('foo', 1, 2, 0);
    IF VAR_numDocs <> 2 THEN
        RAISE EXCEPTION 'failed - %(limit, got %)', VAR_testName, VAR_numDocs;
    END IF;

    SELECT * INTO VAR_r FROM fetchq.queue_top('foo', 1, 1, 1);
    IF VAR_r.subject <> 'a5' THEN
        RAISE EXCEPTION 'failed - %(offset, got %)', VAR_testName, VAR_r.subject;
    END IF;

    passed = TRUE;
END; $$
LANGUAGE plpgsql;
