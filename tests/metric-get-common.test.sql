CREATE OR REPLACE FUNCTION fetchq_test.metric_get_common_01(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'COULD NOT GET COMMON METRICS';
    VAR_r RECORD;
    VAR_sum INTEGER = 0;
BEGIN

    -- initialize test


    -- set counters
    PERFORM fetchq.metric_set('a', 'cnt', 1);
    PERFORM fetchq.metric_set('a', 'pnd', 2);
    PERFORM fetchq.metric_set('a', 'pln', 3);
    PERFORM fetchq.metric_set('a', 'act', 4);
    PERFORM fetchq.metric_set('a', 'cpl', 5);
    PERFORM fetchq.metric_set('a', 'kll', 6);
    PERFORM fetchq.metric_set('a', 'ent', 7);
    PERFORM fetchq.metric_set('a', 'drp', 8);
    PERFORM fetchq.metric_set('a', 'pkd', 9);
    PERFORM fetchq.metric_set('a', 'prc', 10);
    PERFORM fetchq.metric_set('a', 'res', 11);
    PERFORM fetchq.metric_set('a', 'rej', 12);
    PERFORM fetchq.metric_set('a', 'orp', 13);
    PERFORM fetchq.metric_set('a', 'err', 14);
    PERFORM fetchq.metric_log_pack();

    -- run the test
    SELECT * INTO VAR_r FROM fetchq.metric_get_common('a');
    VAR_sum = VAR_sum + VAR_r.cnt;
    VAR_sum = VAR_sum + VAR_r.pnd;
    VAR_sum = VAR_sum + VAR_r.pln;
    VAR_sum = VAR_sum + VAR_r.act;
    VAR_sum = VAR_sum + VAR_r.cpl;
    VAR_sum = VAR_sum + VAR_r.kll;
    VAR_sum = VAR_sum + VAR_r.ent;
    VAR_sum = VAR_sum + VAR_r.drp;
    VAR_sum = VAR_sum + VAR_r.pkd;
    VAR_sum = VAR_sum + VAR_r.prc;
    VAR_sum = VAR_sum + VAR_r.res;
    VAR_sum = VAR_sum + VAR_r.rej;
    VAR_sum = VAR_sum + VAR_r.orp;
    VAR_sum = VAR_sum + VAR_r.err;
    
    IF VAR_sum <> 105 THEN
        RAISE EXCEPTION 'failed - %(current_value, expected "105", got "%")', VAR_testName, VAR_sum;
    END IF;

    passed = TRUE;
END; $$
LANGUAGE plpgsql;
