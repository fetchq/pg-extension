
CREATE OR REPLACE FUNCTION fetchq_test.metric_get_total_01(
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'COULD NOT GET TOTAL FOR A METRIC';
    VAR_r RECORD;
BEGIN

    -- initialize test


    -- set counters
    PERFORM fetchq.metric_set('a', 'tot', 1);
    PERFORM fetchq.metric_set('b', 'tot', 3);
    PERFORM fetchq.metric_log_increment('a', 'tot', 1);
    PERFORM fetchq.metric_log_decrement('b', 'tot', 1);
    PERFORM fetchq.metric_log_pack();

    -- run the test
    SELECT * INTO VAR_r FROM fetchq.metric_get_total('tot');
    
    -- test result rows
    IF VAR_r.current_value <> 4 THEN
        RAISE EXCEPTION 'failed - %(current_value, expected "4", got "%")', VAR_testName, VAR_r.current_value;
    END IF;

    passed = TRUE;
END; $$
LANGUAGE plpgsql;
