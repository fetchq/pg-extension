
-- It should truncate only a queue data
CREATE OR REPLACE FUNCTION fetchq_test.queue_truncate_01() RETURNS void 
SET client_min_messages = error
AS $$
DECLARE
	VAR_numDocs INTEGER;
    VAR_r RECORD;
BEGIN
    PERFORM fetchq.queue_create('foo');

    -- create & drop the queue
    PERFORM fetchq.doc_push('foo', 'a1', 0, 0, NOW() + INTERVAL '1m', '{}');
    PERFORM fetchq.doc_push('foo', 'a2', 0, 0, NOW() - INTERVAL '1m', '{}');

    PERFORM fetchq.log_error('foo', 'a1', 'some error', '{"a":1}');
    
    PERFORM fetchq.mnt();
    PERFORM fetchq.metric_snap('foo');

    SELECT * INTO VAR_r FROM fetchq.metric_get('foo', 'cnt');
    PERFORM fetchq_test.expect_equalInt(VAR_r.current_value, 2, 'before truncate #01');

    SELECT COUNT(*) AS current_value INTO VAR_r FROM fetchq_data.foo__logs;
    PERFORM fetchq_test.expect_equalInt(VAR_r.current_value::int, 1, 'before truncate #02');
    
    SELECT COUNT(*) AS current_value INTO VAR_r FROM fetchq_data.foo__metrics;
    PERFORM fetchq_test.expect_equalInt(VAR_r.current_value::int, 5, 'before truncate #03');

    SELECT COUNT(*) AS current_value INTO VAR_r FROM fetchq.jobs WHERE queue = 'foo' AND iterations > 0;
    PERFORM fetchq_test.expect_equalInt(VAR_r.current_value::int, 4, 'before truncate #04');

    PERFORM fetchq.queue_truncate('foo');

    SELECT * INTO VAR_r FROM fetchq.metric_get('foo', 'cnt');
    PERFORM fetchq_test.expect_equalInt(VAR_r.current_value, 0, 'after truncate #01');

    -- metrics should be unaffected
    SELECT COUNT(*) AS current_value INTO VAR_r FROM fetchq_data.foo__metrics;
    PERFORM fetchq_test.expect_equalInt(VAR_r.current_value::int, 5, 'after truncate #02');

    -- logs should be unaffected
    SELECT COUNT(*) AS current_value INTO VAR_r FROM fetchq_data.foo__logs;
    PERFORM fetchq_test.expect_equalInt(VAR_r.current_value::int, 1, 'after truncate #03');

    -- jobs should be uneffected
    SELECT COUNT(*) AS current_value INTO VAR_r FROM fetchq.jobs WHERE queue = 'foo' AND iterations > 0;
    PERFORM fetchq_test.expect_equalInt(VAR_r.current_value::int, 4, 'after truncate #04');

END; $$
LANGUAGE plpgsql;

-- It should truncate a queue, also with logs and metrics
-- TODO: refactor me
CREATE OR REPLACE FUNCTION fetchq_test.queue_truncate_02(
    OUT passed BOOLEAN
) AS $$
DECLARE
	VAR_numDocs INTEGER;
    VAR_r RECORD;
BEGIN
    PERFORM fetchq.queue_create('foo');
    UPDATE fetchq.jobs SET next_iteration = NOW() - INTERVAL '1h' WHERE queue = 'foo';

    -- create & drop the queue
    PERFORM fetchq.doc_push('foo', 'a1', 0, 0, NOW() + INTERVAL '1m', '{}');
    PERFORM fetchq.doc_push('foo', 'a2', 0, 0, NOW() - INTERVAL '1m', '{}');

    PERFORM fetchq.log_error('foo', 'a1', 'some error', '{"a":1}');

    PERFORM fetchq.mnt();
    PERFORM fetchq.metric_snap('foo');

    SELECT * INTO VAR_r FROM fetchq.metric_get('foo', 'cnt');
    IF VAR_r.current_value != 2 THEN
        RAISE EXCEPTION 'failed count documents before truncate - (expected 2, got %)', VAR_r.current_value;
    END IF;

    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_data.foo__metrics;
    IF VAR_numDocs != 5 THEN
        RAISE EXCEPTION 'failed count metrics before truncate - (expected 5, got %)', VAR_numDocs;
    END IF;

    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_data.foo__logs;
    IF VAR_numDocs != 1 THEN
        RAISE EXCEPTION 'failed count logs before truncate - (expected 1, got %)', VAR_numDocs;
    END IF;

    PERFORM fetchq.queue_truncate('foo', true);

    SELECT * INTO VAR_r FROM fetchq.metric_get('foo', 'cnt');
    IF VAR_r.current_value != 0 THEN
        RAISE EXCEPTION 'failed count documents after truncate - (expected 0, got %)', VAR_r.current_value;
    END IF;

    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_data.foo__metrics;
    IF VAR_numDocs != 0 THEN
        RAISE EXCEPTION 'failed count metrics after truncate - (expected 0, got %)', VAR_numDocs;
    END IF;

    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_data.foo__logs;
    IF VAR_numDocs != 0 THEN
        RAISE EXCEPTION 'failed count logs after truncate - (expected 0, got %)', VAR_numDocs;
    END IF;

    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq.jobs WHERE queue = 'foo' AND iterations > 0;
    IF VAR_numDocs != 0 THEN
        RAISE EXCEPTION 'failed count jobs counters after truncate - (expected 0, got %)', VAR_numDocs;
    END IF;

    passed = TRUE;
END; $$
LANGUAGE plpgsql;

-- It should truncate all existing queues data
-- TODO: refactor me
CREATE OR REPLACE FUNCTION fetchq_test.queue_truncate_all_01(
    OUT passed BOOLEAN
) AS $$
DECLARE
	VAR_numDocs INTEGER;
    VAR_r RECORD;
BEGIN
    PERFORM fetchq.queue_create('foo');
    PERFORM fetchq.queue_create('faa');

    -- create & drop the queue
    PERFORM fetchq.doc_push('foo', 'a1', 0, 0, NOW() + INTERVAL '1m', '{}');
    PERFORM fetchq.doc_push('faa', 'a2', 0, 0, NOW() - INTERVAL '1m', '{}');

    PERFORM fetchq.log_error('foo', 'a1', 'some error', '{"a":1}');
    PERFORM fetchq.log_error('faa', 'a2', 'some error', '{"a":1}');

    PERFORM fetchq.mnt();
    PERFORM fetchq.metric_snap('foo');
    PERFORM fetchq.metric_snap('faa');

    SELECT * INTO VAR_r FROM fetchq.metric_get('foo', 'cnt');
    IF VAR_r.current_value != 1 THEN
        RAISE EXCEPTION 'foo: failed count documents before truncate - (expected 1, got %)', VAR_r.current_value;
    END IF;

    SELECT * INTO VAR_r FROM fetchq.metric_get('faa', 'cnt');
    IF VAR_r.current_value != 1 THEN
        RAISE EXCEPTION 'faa: failed count documents before truncate - (expected 1, got %)', VAR_r.current_value;
    END IF;

    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_data.foo__metrics;
    IF VAR_numDocs != 4 THEN
        RAISE EXCEPTION 'foo: failed count metrics before truncate - (expected 4, got %)', VAR_numDocs;
    END IF;

    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_data.faa__metrics;
    IF VAR_numDocs != 4 THEN
        RAISE EXCEPTION 'faa: failed count metrics before truncate - (expected 4, got %)', VAR_numDocs;
    END IF;

    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_data.foo__logs;
    IF VAR_numDocs != 1 THEN
        RAISE EXCEPTION 'foo: failed count logs before truncate - (expected 1, got %)', VAR_numDocs;
    END IF;

    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_data.faa__logs;
    IF VAR_numDocs != 1 THEN
        RAISE EXCEPTION 'faa: failed count logs before truncate - (expected 1, got %)', VAR_numDocs;
    END IF;

    PERFORM fetchq.queue_truncate_all();

    SELECT * INTO VAR_r FROM fetchq.metric_get('foo', 'cnt');
    IF VAR_r.current_value != 0 THEN
        RAISE EXCEPTION 'foo: failed count documents after truncate - (expected 0, got %)', VAR_r.current_value;
    END IF;

    SELECT * INTO VAR_r FROM fetchq.metric_get('faa', 'cnt');
    IF VAR_r.current_value != 0 THEN
        RAISE EXCEPTION 'faa: failed count documents after truncate - (expected 0, got %)', VAR_r.current_value;
    END IF;

    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_data.foo__metrics;
    IF VAR_numDocs != 4 THEN
        RAISE EXCEPTION 'foo: failed count metrics after truncate - (expected 4, got %)', VAR_numDocs;
    END IF;

    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_data.faa__metrics;
    IF VAR_numDocs != 4 THEN
        RAISE EXCEPTION 'faa: failed count metrics after truncate - (expected 4, got %)', VAR_numDocs;
    END IF;

    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_data.foo__logs;
    IF VAR_numDocs != 1 THEN
        RAISE EXCEPTION 'foo: failed count logs after truncate - (expected 1, got %)', VAR_numDocs;
    END IF;

    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_data.faa__logs;
    IF VAR_numDocs != 1 THEN
        RAISE EXCEPTION 'faa: failed count logs after truncate - (expected 1, got %)', VAR_numDocs;
    END IF;

    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq.jobs WHERE queue = 'foo' AND iterations > 0;
    IF VAR_numDocs != 4 THEN
        RAISE EXCEPTION 'foo: failed count jobs counters after truncate - (expected 4, got %)', VAR_numDocs;
    END IF;

    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq.jobs WHERE queue = 'faa' AND iterations > 0;
    IF VAR_numDocs != 4 THEN
        RAISE EXCEPTION 'faa: failed count jobs counters after truncate - (expected 4, got %)', VAR_numDocs;
    END IF;

    passed = TRUE;
END; $$
LANGUAGE plpgsql;

-- It should truncate all existing queues, also with logs and metrics
-- TODO: refactor me
CREATE OR REPLACE FUNCTION fetchq_test.queue_truncate_all_02(
    OUT passed BOOLEAN
) AS $$
DECLARE
	VAR_numDocs INTEGER;
    VAR_r RECORD;
BEGIN
    PERFORM fetchq.queue_create('foo');
    PERFORM fetchq.queue_create('faa');

    -- create & drop the queue
    PERFORM fetchq.doc_push('foo', 'a1', 0, 0, NOW() + INTERVAL '1m', '{}');
    PERFORM fetchq.doc_push('faa', 'a2', 0, 0, NOW() - INTERVAL '1m', '{}');

    PERFORM fetchq.log_error('foo', 'a1', 'some error', '{"a":1}');
    PERFORM fetchq.log_error('faa', 'a2', 'some error', '{"a":1}');

    PERFORM fetchq.mnt();
    PERFORM fetchq.metric_snap('foo');
    PERFORM fetchq.metric_snap('faa');

    SELECT * INTO VAR_r FROM fetchq.metric_get('foo', 'cnt');
    IF VAR_r.current_value != 1 THEN
        RAISE EXCEPTION 'foo: failed count documents before truncate - (expected 1, got %)', VAR_r.current_value;
    END IF;

    SELECT * INTO VAR_r FROM fetchq.metric_get('faa', 'cnt');
    IF VAR_r.current_value != 1 THEN
        RAISE EXCEPTION 'faa: failed count documents before truncate - (expected 1, got %)', VAR_r.current_value;
    END IF;

    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_data.foo__metrics;
    IF VAR_numDocs != 4 THEN
        RAISE EXCEPTION 'foo: failed count metrics before truncate - (expected 4, got %)', VAR_numDocs;
    END IF;

    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_data.faa__metrics;
    IF VAR_numDocs != 4 THEN
        RAISE EXCEPTION 'faa: failed count metrics before truncate - (expected 4, got %)', VAR_numDocs;
    END IF;

    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_data.foo__logs;
    IF VAR_numDocs != 1 THEN
        RAISE EXCEPTION 'foo: failed count logs before truncate - (expected 1, got %)', VAR_numDocs;
    END IF;

    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_data.faa__logs;
    IF VAR_numDocs != 1 THEN
        RAISE EXCEPTION 'faa: failed count logs before truncate - (expected 1, got %)', VAR_numDocs;
    END IF;

    PERFORM fetchq.queue_truncate_all(true);

    SELECT * INTO VAR_r FROM fetchq.metric_get('foo', 'cnt');
    IF VAR_r.current_value != 0 THEN
        RAISE EXCEPTION 'foo: failed count documents after truncate - (expected 0, got %)', VAR_r.current_value;
    END IF;

    SELECT * INTO VAR_r FROM fetchq.metric_get('faa', 'cnt');
    IF VAR_r.current_value != 0 THEN
        RAISE EXCEPTION 'faa: failed count documents after truncate - (expected 0, got %)', VAR_r.current_value;
    END IF;

    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_data.foo__metrics;
    IF VAR_numDocs != 0 THEN
        RAISE EXCEPTION 'foo: failed count metrics after truncate - (expected 0, got %)', VAR_numDocs;
    END IF;

    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_data.faa__metrics;
    IF VAR_numDocs != 0 THEN
        RAISE EXCEPTION 'faa: failed count metrics after truncate - (expected 0, got %)', VAR_numDocs;
    END IF;

    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_data.foo__logs;
    IF VAR_numDocs != 0 THEN
        RAISE EXCEPTION 'foo: failed count logs after truncate - (expected 0, got %)', VAR_numDocs;
    END IF;

    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq_data.faa__logs;
    IF VAR_numDocs != 0 THEN
        RAISE EXCEPTION 'faa: failed count logs after truncate - (expected 0, got %)', VAR_numDocs;
    END IF;

    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq.jobs WHERE queue = 'foo' AND iterations > 0;
    IF VAR_numDocs != 0 THEN
        RAISE EXCEPTION 'foo: failed count jobs counters after truncate - (expected 0, got %)', VAR_numDocs;
    END IF;

    SELECT COUNT(*) INTO VAR_numDocs FROM fetchq.jobs WHERE queue = 'faa' AND iterations > 0;
    IF VAR_numDocs != 0 THEN
        RAISE EXCEPTION 'faa: failed count jobs counters after truncate - (expected 0, got %)', VAR_numDocs;
    END IF;

    passed = TRUE;
END; $$
LANGUAGE plpgsql;