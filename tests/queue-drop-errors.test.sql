-- declare test case
CREATE OR REPLACE FUNCTION fetchq_test__queue_drop_errors_01 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'IT SHOULD DROP ERRORS AFTER A GIVEN RETENTION STRING';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();
    PERFORM fetchq_queue_create('foo');

    INSERT INTO fetchq__foo__errors ( created_at, subject, message ) VALUES
    ( NOW(), 'a', 'b' ),
    ( NOW() - INTERVAL '1d', 'a', 'b' ),
    ( NOW() - INTERVAL '2d', 'a', 'b' );

    SELECT * INTO VAR_r FROM fetchq_queue_drop_errors('foo', '24 hours');
    IF VAR_r.affected_rows IS NULL THEN
        RAISE EXCEPTION 'failed - (null value) %', VAR_testName;
    END IF;
    IF VAR_r.affected_rows != 1 THEN
        RAISE EXCEPTION 'failed - (expected: 1, got: %) %', VAR_r.affected_rows, VAR_testName;
    END IF;

    -- cleanup
    PERFORM fetchq_test_clean();
    passed = TRUE;
END; $$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION fetchq_test__queue_drop_errors_02 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'IT SHOULD DROP ERRORS AFTER A RETENTION DATE';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();
    PERFORM fetchq_queue_create('foo');

    INSERT INTO fetchq__foo__errors ( created_at, subject, message ) VALUES
    ( NOW(), 'a', 'b' ),
    ( NOW() - INTERVAL '1d', 'a', 'b' ),
    ( NOW() - INTERVAL '2d', 'a', 'b' );

    SELECT * INTO VAR_r FROM fetchq_queue_drop_errors('foo', NOW() - INTERVAL '24h');
    IF VAR_r.affected_rows IS NULL THEN
        RAISE EXCEPTION 'failed - (null value) %', VAR_testName;
    END IF;
    IF VAR_r.affected_rows != 1 THEN
        RAISE EXCEPTION 'failed - (expected: 1, got: %) %', VAR_r.affected_rows, VAR_testName;
    END IF;

    -- cleanup
    PERFORM fetchq_test_clean();
    passed = TRUE;
END; $$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fetchq_test__queue_drop_errors_03 (
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'IT SHOULD DROP ERRORS USING THE QUEUE SETTINGS';
    VAR_r RECORD;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();
    PERFORM fetchq_queue_create('foo');
    PERFORM fetchq_queue_set_errors_retention('foo', '1h');

    INSERT INTO fetchq__foo__errors ( created_at, subject, message ) VALUES
    ( NOW(), 'a', 'b' ),
    ( NOW() - INTERVAL '1d', 'a', 'b' ),
    ( NOW() - INTERVAL '2d', 'a', 'b' );

    SELECT * INTO VAR_r FROM fetchq_queue_drop_errors('foo');
    IF VAR_r.affected_rows IS NULL THEN
        RAISE EXCEPTION 'failed - (null value) %', VAR_testName;
    END IF;
    IF VAR_r.affected_rows != 2 THEN
        RAISE EXCEPTION 'failed - (expected: 2, got: %) %', VAR_r.affected_rows, VAR_testName;
    END IF;

    -- cleanup
    PERFORM fetchq_test_clean();
    passed = TRUE;
END; $$
LANGUAGE plpgsql;
