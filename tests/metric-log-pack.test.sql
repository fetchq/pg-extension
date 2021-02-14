
CREATE OR REPLACE FUNCTION fetchq_test.metric_log_pack_01(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'SHOULD PACK WRITES';
    VAR_r RECORD;
BEGIN
    
    -- initialize test


    -- set some basic metrics
    PERFORM fetchq.metric_log_set('foo', 'cnt', 10);
    PERFORM fetchq.metric_log_increment('foo', 'cnt', 5);
    PERFORM fetchq.metric_log_decrement('foo', 'cnt', 2);

    -- fake some future metrics
    INSERT INTO fetchq.metrics_writes
   (created_at, queue, metric, increment, reset)
    VALUES
   (NOW() + INTERVAL '1s', 'foo', 'cnt', 1, null);
    

    -- run maintenance
    PERFORM fetchq.mnt_run_all(100);
    SELECT * INTO VAR_r FROM fetchq.metric_log_pack();
    IF VAR_r.affected_rows <> 3 THEN
        RAISE EXCEPTION 'failed affected rows - %(count, expected 2, received %)', VAR_testName, VAR_r.affected_rows;
    END IF;

    SELECT * INTO VAR_r FROM fetchq.metric_get('foo', 'cnt');
    IF VAR_r.current_value <> 13 THEN
        RAISE EXCEPTION 'failed value - %(count, expected 13, received %)', VAR_testName, VAR_r.current_value;
    END IF;
    

    passed = TRUE;
END; $$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fetchq_test.metric_log_pack_02(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'SHOULD PACK WRITES';
    VAR_expected INTEGER;
    VAR_numDocs INTEGER;
    VAR_r RECORD;
BEGIN
    -- init test
    PERFORM fetchq.queue_create('foo');
    PERFORM fetchq.queue_create('faa');

    -- push items into the queue
    PERFORM fetchq.doc_push('foo', 'a1', 0, 0, NOW() + INTERVAL '1m', '{}');
    PERFORM fetchq.doc_push('faa', 'a1', 0, 0, NOW() + INTERVAL '1m', '{}');
    PERFORM fetchq.doc_push('foo', 'a2', 0, 0, NOW() - INTERVAL '1m', '{}');
    PERFORM fetchq.doc_push('faa', 'a2', 0, 0, NOW() - INTERVAL '1m', '{}');
    PERFORM fetchq.doc_push('faa', 'a3', 0, 0, NOW() - INTERVAL '2m', '{}');
    PERFORM fetchq.mnt();

    SELECT * INTO VAR_r FROM fetchq.metric_get('foo', 'cnt');
    PERFORM fetchq_test.expect_equalInt(VAR_r.current_value, 2, 'foo: failed count total documents (before pick)');

    SELECT * INTO VAR_r FROM fetchq.metric_get('foo', 'pln');
    PERFORM fetchq_test.expect_equalInt(VAR_r.current_value, 1, 'foo: failed count planned documents (before pick)');

    SELECT * INTO VAR_r FROM fetchq.metric_get('foo', 'pnd');
    PERFORM fetchq_test.expect_equalInt(VAR_r.current_value, 1, 'foo: failed count pending documents (before pick)');

    SELECT * INTO VAR_r FROM fetchq.metric_get('foo', 'ent');
    PERFORM fetchq_test.expect_equalInt(VAR_r.current_value, 2, 'foo: failed count entered documents (before pick)');

    SELECT * INTO VAR_r FROM fetchq.metric_get('faa', 'cnt');
    PERFORM fetchq_test.expect_equalInt(VAR_r.current_value, 3, 'faa: failed count total documents (before pick)');

    SELECT * INTO VAR_r FROM fetchq.metric_get('faa', 'pln');
    PERFORM fetchq_test.expect_equalInt(VAR_r.current_value, 1, 'faa: failed count planned documents (before pick)');

    SELECT * INTO VAR_r FROM fetchq.metric_get('faa', 'pnd');
    PERFORM fetchq_test.expect_equalInt(VAR_r.current_value, 2, 'faa: failed count pending documents (before pick)');

    SELECT * INTO VAR_r FROM fetchq.metric_get('faa', 'ent');
    PERFORM fetchq_test.expect_equalInt(VAR_r.current_value, 3, 'faa: failed count entered documents (before pick)');


    -- pick and complete
    SELECT * INTO VAR_r FROM fetchq.doc_pick('faa', 0, 1, '5m');
    PERFORM fetchq.doc_complete('faa', VAR_r.subject);    
    PERFORM fetchq.mnt();

    SELECT * INTO VAR_r FROM fetchq.metric_get('faa', 'pnd');
    PERFORM fetchq_test.expect_equalInt(VAR_r.current_value, 1, 'faa: failed count pending documents (after pick)');

    SELECT * INTO VAR_r FROM fetchq.metric_get('faa', 'cpl');
    PERFORM fetchq_test.expect_equalInt(VAR_r.current_value, 1, 'faa: failed count completed documents (after pick)');
    
    passed = TRUE;
END; $$
LANGUAGE plpgsql;