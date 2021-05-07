-- It should be possible to run a maintanance job for all the existing queues
CREATE OR REPLACE FUNCTION fetchq_test.upgrade__320__330() RETURNS void AS $$
DECLARE
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq.queue_create('foo');
    PERFORM fetchq.queue_create('faa');

    -- insert dummy data & force the date in the past
    PERFORM fetchq.doc_push('foo', 'a1', 0, 0, NOW(), '{}');
    PERFORM fetchq.doc_push('foo', 'a2', 0, 0, NOW() + INTERVAL '1s', '{}');
    PERFORM fetchq.doc_push('foo', 'a3', 0, 0, NOW() - INTERVAL '1s', '{}');
    
    -- run the upgrade script
    PERFORM fetchq.upgrade__320__330();
END; $$
LANGUAGE plpgsql;

