
CREATE OR REPLACE FUNCTION fetchq_test__metric_compute_01 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'COULD NOT COMPUTE QUEUE METRICS';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();
    PERFORM fetchq_queue_create('foo');

    -- insert dummy data
    PERFORM fetchq_doc_push('foo', 'a1', 0, 1, NOW() - INTERVAL '10s', '{}');
    PERFORM fetchq_doc_push('foo', 'a2', 0, 1, NOW() - INTERVAL '9s', '{}');
    PERFORM fetchq_doc_push('foo', 'a3', 0, 1, NOW() - INTERVAL '8s', '{}');
    PERFORM fetchq_doc_push('foo', 'a4', 0, 1, NOW() - INTERVAL '7s', '{}');
    PERFORM fetchq_doc_push('foo', 'a5', 0, 1, NOW() - INTERVAL '6s', '{}');
    
    SELECT * INTO VAR_r FROM fetchq_doc_pick('foo', 0, 1, '5m');
    PERFORM fetchq_doc_reschedule('foo', VAR_r.subject, NOW() + INTERVAL '1y');

    SELECT * INTO VAR_r FROM fetchq_doc_pick('foo', 0, 1, '5m');
    PERFORM fetchq_doc_reject('foo', VAR_r.subject, 'foo', '{"a":1}');

    SELECT * INTO VAR_r FROM fetchq_doc_pick('foo', 0, 1, '5m');
    PERFORM fetchq_doc_complete('foo', VAR_r.subject);

    SELECT * INTO VAR_r FROM fetchq_doc_pick('foo', 0, 1, '5m');
    PERFORM fetchq_doc_kill('foo', VAR_r.subject);

    SELECT * INTO VAR_r FROM fetchq_doc_pick('foo', 0, 1, '5m');
    PERFORM fetchq_doc_drop('foo', VAR_r.subject);

    PERFORM fetchq_mnt_run_all(100);
    PERFORM fetchq_metric_log_pack();

    -- get computed metrics
    SELECT * INTO VAR_r from fetchq_metric_compute('foo');
    IF VAR_r.cnt <> 4 THEN
        RAISE EXCEPTION 'failed - % (cnt, expected "4", got "%")', VAR_testName, VAR_r.cnt;
    END IF;
    IF VAR_r.pln <> 1 THEN
        RAISE EXCEPTION 'failed - % (pln, expected "1", got "%")', VAR_testName, VAR_r.pln;
    END IF;
    IF VAR_r.pnd <> 1 THEN
        RAISE EXCEPTION 'failed - % (pnd, expected "1", got "%")', VAR_testName, VAR_r.pnd;
    END IF;
    IF VAR_r.kll <> 1 THEN
        RAISE EXCEPTION 'failed - % (kll, expected "1", got "%")', VAR_testName, VAR_r.kll;
    END IF;
    IF VAR_r.cpl <> 1 THEN
        RAISE EXCEPTION 'failed - % (cpl, expected "1", got "%")', VAR_testName, VAR_r.cpl;
    END IF;
    IF VAR_r.act <> 0 THEN
        RAISE EXCEPTION 'failed - % (act, expected "1", got "%")', VAR_testName, VAR_r.act;
    END IF;

    -- cleanup
    PERFORM fetchq_test_clean();

    passed = TRUE;
END; $$
LANGUAGE plpgsql;

