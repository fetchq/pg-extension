

CREATE OR REPLACE FUNCTION fetchq_test__doc_upsert_01 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'SHOULD BE ABLE TO UPSERT (INSERT) A SINGLE DOCUMENT';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();
    PERFORM fetchq_queue_create('foo');

    -- should be able to queue a document
    SELECT * INTO VAR_r FROM fetchq_doc_upsert('foo', 'a1', 0, 0, NOW() + INTERVAL '1m', '{}');
    IF VAR_r.queued_docs IS NULL THEN
        RAISE EXCEPTION 'failed (null value) - %', VAR_testName;
    END IF;
    IF VAR_r.queued_docs <> 1 THEN
        RAISE EXCEPTION 'failed (expected: 1, received: %) - %', VAR_r.queued_docs, VAR_testName;
    END IF;

    -- should be able to update such document
    SELECT * INTO VAR_r FROM fetchq_doc_upsert('foo', 'a1', 0, 1, '2222-11-10 12:00', '{"a":1}');
    IF VAR_r.updated_docs IS NULL THEN
        RAISE EXCEPTION 'failed (null value on update) - %', VAR_testName;
    END IF;
    IF VAR_r.updated_docs <> 1 THEN
        RAISE EXCEPTION 'failed (expected: 1, received: %) - %', VAR_r.updated_docs, VAR_testName;
    END IF;

    -- cleanup test
    PERFORM fetchq_test_clean();
    passed = TRUE;
END; $$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fetchq_test__doc_upsert_02 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'SHOULD NOT BE ABLE TO UPSERT AN ACTIVE DOCUMENT';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();
    PERFORM fetchq_queue_create('foo');

    -- should be able to queue a document
    SELECT * INTO VAR_r FROM fetchq_doc_upsert('foo', 'a1', 0, 0, NOW() - INTERVAL '1m', '{}');
    IF VAR_r.queued_docs IS NULL THEN
        RAISE EXCEPTION 'failed (null value) - %', VAR_testName;
    END IF;
    IF VAR_r.queued_docs <> 1 THEN
        RAISE EXCEPTION 'failed (expected: 1, received: %) - %', VAR_r.queued_docs, VAR_testName;
    END IF;

    PERFORM fetchq_doc_pick('foo', 0, 1, '5m');

    -- should be able to update such document
    SELECT * INTO VAR_r FROM fetchq_doc_upsert('foo', 'a1', 0, 1, '2222-11-10 12:00', '{"a":1}');
    IF VAR_r.updated_docs IS NULL THEN
        RAISE EXCEPTION 'failed (null value on update) - %', VAR_testName;
    END IF;
    IF VAR_r.updated_docs <> 0 THEN
        RAISE EXCEPTION 'failed (expected: 0, received: %) - %', VAR_r.updated_docs, VAR_testName;
    END IF;

    -- cleanup test
    -- PERFORM fetchq_test_clean();
    passed = TRUE;
END; $$
LANGUAGE plpgsql;