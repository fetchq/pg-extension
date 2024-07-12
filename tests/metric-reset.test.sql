
CREATE OR REPLACE FUNCTION fetchq_test.metric_reset_01(
    OUT passed BOOLEAN
) AS $$
DECLARE
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

    -- run maintenance
    PERFORM fetchq.mnt_run_all(100);
    PERFORM fetchq.metric_log_pack();

    -- get computed metrics
    SELECT * INTO VAR_r from fetchq.metric_reset('foo');

    -- test on results
    IF VAR_r.cnt IS NULL THEN
        RAISE EXCEPTION 'cnt, got null value';
    END IF;
    IF VAR_r.cnt <> 4 THEN
        RAISE EXCEPTION 'cnt, expected "4", got "%"', VAR_r.cnt;
    END IF;
    IF VAR_r.pln <> 1 THEN
        RAISE EXCEPTION 'pln, expected "1", got "%"', VAR_r.pln;
    END IF;
    IF VAR_r.pnd <> 1 THEN
        RAISE EXCEPTION 'pnd, expected "1", got "%"', VAR_r.pnd;
    END IF;
    IF VAR_r.kll <> 1 THEN
        RAISE EXCEPTION 'kll, expected "1", got "%"', VAR_r.kll;
    END IF;
    IF VAR_r.cpl <> 1 THEN
        RAISE EXCEPTION 'cpl, expected "1", got "%"', VAR_r.cpl;
    END IF;
    IF VAR_r.act <> 0 THEN
        RAISE EXCEPTION 'act, expected "1", got "%"', VAR_r.act;
    END IF;


    passed = TRUE;
END; $$
LANGUAGE plpgsql;

