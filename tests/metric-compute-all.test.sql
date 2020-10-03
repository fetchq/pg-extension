
CREATE OR REPLACE FUNCTION fetchq_test.metric_compute_all_01(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'COULD NOT COMPUTE ALL QUEUE METRICS';
    VAR_affectedRows INTEGER;
    VAR_r RECORD;
BEGIN
    
    -- initialize test

    
    -- insert dummy data - queue foo
    PERFORM fetchq.queue_create('foo');
    PERFORM fetchq.doc_push('foo', 'a1', 0, 1, NOW() - INTERVAL '10s', '{}');
    PERFORM fetchq.doc_push('foo', 'a2', 0, 1, NOW() - INTERVAL '9s', '{}');
    PERFORM fetchq.doc_push('foo', 'a3', 0, 1, NOW() - INTERVAL '8s', '{}');
    PERFORM fetchq.doc_push('foo', 'a4', 0, 1, NOW() - INTERVAL '7s', '{}');
    PERFORM fetchq.doc_push('foo', 'a5', 0, 1, NOW() - INTERVAL '6s', '{}');
    SELECT * INTO VAR_r FROM fetchq.doc_pick('foo', 0, 1, '5m');
    PERFORM fetchq.doc_reschedule('foo', VAR_r.subject, NOW() + INTERVAL '1y');
    SELECT * INTO VAR_r FROM fetchq.doc_pick('foo', 0, 1, '5m');
    PERFORM fetchq.doc_reject('foo', VAR_r.subject, 'foo', '{"a":1}');
    SELECT * INTO VAR_r FROM fetchq.doc_pick('foo', 0, 1, '5m');
    PERFORM fetchq.doc_complete('foo', VAR_r.subject);
    SELECT * INTO VAR_r FROM fetchq.doc_pick('foo', 0, 1, '5m');
    PERFORM fetchq.doc_kill('foo', VAR_r.subject);
    SELECT * INTO VAR_r FROM fetchq.doc_pick('foo', 0, 1, '5m');
    PERFORM fetchq.doc_drop('foo', VAR_r.subject);

    -- insert dummy data - queue faa
    PERFORM fetchq.queue_create('faa');
    PERFORM fetchq.doc_push('faa', 'a1', 0, 1, NOW() - INTERVAL '10s', '{}');
    PERFORM fetchq.doc_push('faa', 'a2', 0, 1, NOW() - INTERVAL '9s', '{}');
    PERFORM fetchq.doc_push('faa', 'a3', 0, 1, NOW() - INTERVAL '8s', '{}');
    PERFORM fetchq.doc_push('faa', 'a4', 0, 1, NOW() - INTERVAL '7s', '{}');
    PERFORM fetchq.doc_push('faa', 'a5', 0, 1, NOW() - INTERVAL '6s', '{}');
    SELECT * INTO VAR_r FROM fetchq.doc_pick('faa', 0, 1, '5m');
    PERFORM fetchq.doc_reschedule('faa', VAR_r.subject, NOW() + INTERVAL '1y');
    SELECT * INTO VAR_r FROM fetchq.doc_pick('faa', 0, 1, '5m');
    PERFORM fetchq.doc_reject('faa', VAR_r.subject, 'faa', '{"a":1}');
    SELECT * INTO VAR_r FROM fetchq.doc_pick('faa', 0, 1, '5m');
    PERFORM fetchq.doc_complete('faa', VAR_r.subject);
    SELECT * INTO VAR_r FROM fetchq.doc_pick('faa', 0, 1, '5m');
    PERFORM fetchq.doc_kill('faa', VAR_r.subject);
    SELECT * INTO VAR_r FROM fetchq.doc_pick('faa', 0, 1, '5m');
    PERFORM fetchq.doc_drop('faa', VAR_r.subject);

    -- compute maintenance
    PERFORM fetchq.mnt_run_all(100);
    PERFORM fetchq.metric_log_pack();

    -- get all computed metrics
    PERFORM fetchq.metric_compute_all();
    GET DIAGNOSTICS VAR_affectedRows := ROW_COUNT;
    IF VAR_affectedRows <> 2 THEN
        RAISE EXCEPTION 'failed - %(count, expected 2, received %)', VAR_testName, VAR_affectedRows;
    END IF;
    

    passed = TRUE;
END; $$
LANGUAGE plpgsql;

