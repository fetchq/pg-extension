CREATE OR REPLACE FUNCTION fetchq_test__load_01 (
    PAR_limit INTEGER,
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'LOAD TEST 01 - INSERT ONE BY ONE';
    VAR_r RECORD;
    StartTime timestamptz;
    EndTime timestamptz;
    Delta double precision;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();
    PERFORM fetchq_queue_create('foo');

    -- insert documents one by one
    StartTime := clock_timestamp();
    FOR VAR_r IN
		SELECT generate_series(1, PAR_limit) AS id, md5(random()::text) AS descr
	LOOP
        PERFORM fetchq_doc_push('foo', VAR_r.descr, 0, 0, NOW() + (random() * (NOW() + '60 days' - NOW())) + '-30 days', '{}');
	END LOOP;
    EndTime := clock_timestamp();
    Delta := 1000 * ( extract(epoch from EndTime) - extract(epoch from StartTime) );
    RAISE NOTICE '%', VAR_testName;
    RAISE NOTICE 'Insert Duration in millisecs=%', ROUND(Delta);
    RAISE NOTICE 'Docs/sec: %', ROUND(PAR_limit * 1000 / Delta);

    -- run maintenance
    StartTime := clock_timestamp();
    PERFORM fetchq_mnt_run_all(100000);
    PERFORM fetchq_metric_log_pack();
    EndTime := clock_timestamp();
    Delta := 1000 * ( extract(epoch from EndTime) - extract(epoch from StartTime) );
    RAISE NOTICE 'Maintenance Duration in millisecs=%', ROUND(Delta);
    
    -- cleanup
    PERFORM fetchq_test_clean();

    passed = TRUE;
END; $$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fetchq_test__load_02 (
    PAR_limit INTEGER,
    OUT passed BOOLEAN
) AS $$
DECLARE
    VAR_testName VARCHAR = 'LOAD TEST 02 - bulk insert';
    VAR_q VARCHAR;
    VAR_sq VARCHAR;
    VAR_r RECORD;
    StartTime timestamptz;
    EndTime timestamptz;
    Delta double precision;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();
    PERFORM fetchq_queue_create('foo');

    -- Generate the push command with multiple documents
    StartTime := clock_timestamp();
    VAR_q = 'select * from fetchq_doc_push(''foo'', 0, %s, ''';
    FOR VAR_r IN
		SELECT generate_series(1, PAR_limit - 1) AS id, md5(random()::text) AS descr
	LOOP
        VAR_sq = '(''''%s'''', 0, ''''{}'''', {DATA}),';
        VAR_q = VAR_q || FORMAT(VAR_sq, VAR_r.id);
	END LOOP;
    -- add tail document to avoid comma mistake
    VAR_sq = '(''''tail'''', 0, ''''{}'''', {DATA})'')';
    VAR_q = FORMAT(VAR_q || VAR_sq, 'NOW() + (random() * (NOW() + ''60 days'' - NOW())) + ''-30 days''');
    EndTime := clock_timestamp();
    Delta := 1000 * ( extract(epoch from EndTime) - extract(epoch from StartTime) );
    RAISE NOTICE 'Generate command Duration in millisecs=%', ROUND(Delta);

    -- Run the insert query
    StartTime := clock_timestamp();
    -- RAISE NOTICE '%', VAR_q;
    EXECUTE VAR_q;
    EndTime := clock_timestamp();
    Delta := 1000 * ( extract(epoch from EndTime) - extract(epoch from StartTime) );
    RAISE NOTICE 'Insert Duration in millisecs=%', ROUND(Delta);
    RAISE NOTICE 'Docs/sec: %', ROUND(PAR_limit * 1000 / Delta);

    -- run maintenance
    StartTime := clock_timestamp();
    PERFORM fetchq_mnt_run_all(100000);
    PERFORM fetchq_metric_log_pack();
    EndTime := clock_timestamp();
    Delta := 1000 * ( extract(epoch from EndTime) - extract(epoch from StartTime) );
    RAISE NOTICE 'Maintenance Duration in millisecs=%', ROUND(Delta);

    -- cleanup
    PERFORM fetchq_test_clean();

    passed = TRUE;
END; $$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fetchq_test__load_03_make_query (
    PAR_limit INTEGER,
    PAR_nextIteration TIMESTAMP WITH TIME ZONE,
    OUT query TEXT,
    OUT duration INTEGER
) AS $$
DECLARE
    VAR_q VARCHAR;
    VAR_sq VARCHAR;
    VAR_r RECORD;
    StartTime timestamptz;
    EndTime timestamptz;
    Delta double precision;
BEGIN

    -- Generate the push command with multiple documents
    StartTime := clock_timestamp();
    VAR_q = 'select * from fetchq_doc_push(''foo'', 0, ''%s'', ''';
    FOR VAR_r IN
		SELECT generate_series(1, PAR_limit - 1) AS id, md5(random()::text) AS descr
	LOOP
        VAR_sq = '(''''%s'''', 0, ''''{}'''', {DATA}),';
        VAR_q = VAR_q || FORMAT(VAR_sq, VAR_r.descr);
	END LOOP;
    -- add tail document to avoid comma mistake
    VAR_sq = '(''''tail'''', 0, ''''{}'''', {DATA})'')';
    VAR_q = FORMAT(VAR_q || VAR_sq, PAR_nextIteration);
    EndTime := clock_timestamp();
    Delta := 1000 * ( extract(epoch from EndTime) - extract(epoch from StartTime) );

    query = VAR_q;
    duration = ROUND(Delta);
END; $$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fetchq_test__load_03_run_query (
    PAR_query TEXT,
    OUT duration INTEGER,
    OUT queued_docs INTEGER
) AS $$
DECLARE
    VAR_r RECORD;
    StartTime timestamptz;
    EndTime timestamptz;
    Delta double precision;
BEGIN
    StartTime := clock_timestamp();
    EXECUTE PAR_query INTO VAR_r;
    -- RAISE NOTICE '%', PAR_query;
    EndTime := clock_timestamp();
    Delta := 1000 * ( extract(epoch from EndTime) - extract(epoch from StartTime) );
    duration = ROUND(Delta);
    queued_docs = VAR_r.queued_docs;
END; $$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fetchq_test__load_03_run_maintenance (
    PAR_limit INTEGER,
    OUT duration INTEGER
) AS $$
DECLARE
    VAR_r RECORD;
    StartTime timestamptz;
    EndTime timestamptz;
    Delta double precision;
BEGIN
    StartTime := clock_timestamp();
    PERFORM fetchq_mnt_run_all(PAR_limit);
    PERFORM fetchq_metric_log_pack();
    EndTime := clock_timestamp();
    Delta := 1000 * ( extract(epoch from EndTime) - extract(epoch from StartTime) );
    duration = ROUND(Delta);
END; $$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fetchq_test__load_03_pick_reschedule (
    PAR_queue VARCHAR,
    PAR_limit INTEGER,
    OUT duration INTEGER
) AS $$
DECLARE
    VAR_r RECORD;
    StartTime timestamptz;
    EndTime timestamptz;
    Delta double precision;
BEGIN
    StartTime := clock_timestamp();
    SELECT * INTO VAR_r FROM fetchq_doc_pick(PAR_queue, 0, PAR_limit, '5m');
    RAISE NOTICE '%', VAR_r;
    -- PERFORM fetchq_doc_reschedule(PAR_queue, VAR_r.id, NOW() + INTERVAL '1y');
    EndTime := clock_timestamp();
    Delta := 1000 * ( extract(epoch from EndTime) - extract(epoch from StartTime) );
    duration = ROUND(Delta);
END; $$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fetchq_test__load_03 (
    PAR_iterations INTEGER,
    PAR_docsPerIteration INTEGER,
    OUT passed BOOLEAN,
    OUT docsPerSecond INTEGER
) AS $$
DECLARE
    VAR_testName VARCHAR = 'LOAD TEST 03 - many many many';
    VAR_r RECORD;
    VAR_r1 RECORD;
    VAR_r2 RECORD;
    VAR_r3 RECORD;
    VAR_sumTime INTEGER = 0;
    VAR_sumRecords INTEGER = 0;
BEGIN
    
    -- initialize test
    PERFORM fetchq_test_init();
    PERFORM fetchq_queue_create('foo');

    -- populate documents
    FOR VAR_r IN
		SELECT generate_series(1, PAR_iterations) AS id, md5(random()::text) AS descr
	LOOP
        -- SELECT * INTO VAR_r1 FROM fetchq_test__load_03_make_query(PAR_docsPerIteration, NOW() + (random() * (NOW() + '60 days' - NOW())) + '-30 days');
        SELECT * INTO VAR_r1 FROM fetchq_test__load_03_make_query(PAR_docsPerIteration, NOW() - INTERVAL '30 days');
        SELECT * INTO VAR_r2 FROM fetchq_test__load_03_run_query(VAR_r1.query);
        SELECT * INTO VAR_r3 FROM fetchq_test__load_03_run_maintenance(PAR_docsPerIteration * 2);
        VAR_sumTime = VAR_sumTime + VAR_r2.duration;
        VAR_sumRecords = VAR_sumRecords + VAR_r2.queued_docs;
        docsPerSecond = (VAR_sumRecords * 1000) / VAR_sumTime;
        RAISE NOTICE 'loop %, q:% e:% m:%, % docs/s', VAR_r.id, VAR_r2.queued_docs, VAR_r2.duration, VAR_r3.duration, docsPerSecond;
	END LOOP;

    -- run last maintenance
    PERFORM fetchq_test__load_03_run_maintenance(PAR_iterations * PAR_docsPerIteration);

    -- test pick document performance
    -- VAR_sumTime = 0;
    -- VAR_sumRecords = 0;
    -- FOR VAR_r IN
	-- 	SELECT generate_series(1, 5) AS id
	-- LOOP
    --     SELECT * INTO VAR_r1 FROM fetchq_test__load_03_pick_reschedule('foo', 1);
    --     VAR_sumTime = VAR_sumTime + VAR_r1.duration;
    --     VAR_sumRecords = VAR_sumRecords + 1;
    --     docsPerSecond = (VAR_sumRecords * 1000) / VAR_sumTime;
    --     RAISE NOTICE 'pick & resolve: % docs/s', docsPerSecond;
	-- END LOOP;

    -- SELECT * INTO VAR_r FROM fetchq_doc_pick('foo', 0, 1, '1m');
    -- RAISE NOTICE '%', VAR_r;

    -- cleanup
    -- PERFORM fetchq_test_clean();

    passed = TRUE;
END; $$
LANGUAGE plpgsql;