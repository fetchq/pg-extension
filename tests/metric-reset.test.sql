
CREATE OR REPLACE FUNCTION fetchq_test.fetchq_test__metric_reset_01(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'COULD NOT COMPUTE QUEUE METRICS';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test.fetchq_test_init();
    
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

    -- empty stats so to force recreate
    TRUNCATE __fetchq_metrics;
    TRUNCATE __fetchq_metrics_writes;

    -- get computed metrics
    SELECT * INTO VAR_r from fetchq.metric_reset('foo');
    IF VAR_r.cnt IS NULL THEN
        RAISE EXCEPTION 'failed - %(cnt, got null value)', VAR_testName;
    END IF;
    IF VAR_r.cnt <> 4 THEN
        RAISE EXCEPTION 'failed - %(cnt, expected "4", got "%")', VAR_testName, VAR_r.cnt;
    END IF;
    IF VAR_r.pln <> 1 THEN
        RAISE EXCEPTION 'failed - %(pln, expected "1", got "%")', VAR_testName, VAR_r.pln;
    END IF;
    IF VAR_r.pnd <> 1 THEN
        RAISE EXCEPTION 'failed - %(pnd, expected "1", got "%")', VAR_testName, VAR_r.pnd;
    END IF;
    IF VAR_r.kll <> 1 THEN
        RAISE EXCEPTION 'failed - %(kll, expected "1", got "%")', VAR_testName, VAR_r.kll;
    END IF;
    IF VAR_r.cpl <> 1 THEN
        RAISE EXCEPTION 'failed - %(cpl, expected "1", got "%")', VAR_testName, VAR_r.cpl;
    END IF;
    IF VAR_r.act <> 0 THEN
        RAISE EXCEPTION 'failed - %(act, expected "1", got "%")', VAR_testName, VAR_r.act;
    END IF;

    -- cleanup
    PERFORM fetchq_test.fetchq_test_clean();
    passed = TRUE;
END; $$
LANGUAGE plpgsql;

