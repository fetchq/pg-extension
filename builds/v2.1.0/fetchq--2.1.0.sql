
-- EXTENSION INFO
DROP FUNCTION IF EXISTS fetchq_info();
CREATE OR REPLACE FUNCTION fetchq_info (
    OUT version VARCHAR
) AS $$
BEGIN
	version='2.1.0';
END; $$
LANGUAGE plpgsql;

-- provides a full JSON rapresentation of the event
CREATE OR REPLACE FUNCTION fetchq_trigger_notify_as_json () RETURNS TRIGGER AS $$
DECLARE
	rec RECORD;
    payload TEXT;
    new_data TEXT;
    old_data TEXT;
BEGIN
    -- Set record row depending on operation
    CASE TG_OP
    WHEN 'INSERT' THEN
        rec := NEW;
        new_data = row_to_json(NEW);
        old_data := 'null';
    WHEN 'UPDATE' THEN
        rec := NEW;
        new_data = row_to_json(NEW);
        old_data := row_to_json(OLD);
    WHEN 'DELETE' THEN
        rec := OLD;
        SELECT json_agg(n)::text INTO old_data FROM json_each_text(to_json(OLD)) n;
        old_data := row_to_json(OLD);
        new_data := 'null';
    ELSE
        RAISE EXCEPTION 'Unknown TG_OP: "%". Should not occur!', TG_OP;
    END CASE;

    -- Record to JSON
    

    -- Build the payload
    payload := ''
            || '{'
            || '"timestamp":"' || CURRENT_TIMESTAMP                    || '",'
            || '"operation":"' || TG_OP                                || '",'
            || '"schema":"'    || TG_TABLE_SCHEMA                      || '",'
            || '"table":"'     || TG_TABLE_NAME                        || '",'
            || '"new_data":'   || new_data                             || ','
            || '"old_data":'   || old_data
            || '}';

    -- Notify and return
    PERFORM pg_notify('fetchq_on_change', payload);
	RETURN rec;
END; $$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fetchq_init (
    OUT was_initialized BOOLEAN
) AS $$
BEGIN
    was_initialized = TRUE;

    -- Create the FetchQ Schema
    CREATE SCHEMA IF NOT EXISTS fetchq_catalog;

    -- Queues Register
    CREATE TABLE IF NOT EXISTS fetchq_catalog.fetchq_sys_queues (
        id SERIAL PRIMARY KEY,
        created_at TIMESTAMP WITH TIME ZONE,
        name CHARACTER VARYING(40) NOT NULL,
        is_active BOOLEAN DEFAULT true,
        current_version INTEGER DEFAULT 0,
        max_attempts INTEGER DEFAULT 5,
        errors_retention VARCHAR(25) DEFAULT '24h',
        metrics_retention JSONB DEFAULT '[]',
        config JSONB DEFAULT '{}'
    );

    CREATE TRIGGER fetchq_trigger_sys_queues_insert AFTER INSERT OR UPDATE OR DELETE
	ON fetchq_catalog.fetchq_sys_queues
    FOR EACH ROW EXECUTE PROCEDURE fetchq_trigger_notify_as_json();

    -- Metrics Overview
    CREATE TABLE IF NOT EXISTS fetchq_catalog.fetchq_sys_metrics (
        id SERIAL PRIMARY KEY,
        queue CHARACTER VARYING(40) NOT NULL,
        metric CHARACTER VARYING(40) NOT NULL,
        value BIGINT NOT NULL,
        updated_at TIMESTAMP WITH TIME ZONE
    );

    CREATE INDEX IF NOT EXISTS fetchq_sys_metrics_queue_idx ON fetchq_catalog.fetchq_sys_metrics USING btree (queue);

    -- Metrics Writes
    CREATE TABLE IF NOT EXISTS fetchq_catalog.fetchq_sys_metrics_writes (
        id SERIAL PRIMARY KEY,
        created_at TIMESTAMP WITH TIME ZONE,
        queue CHARACTER VARYING(40) NOT NULL,
        metric CHARACTER VARYING(40) NOT NULL,
        increment BIGINT,
        reset BIGINT
    );

    CREATE INDEX IF NOT EXISTS fetchq_sys_metrics_writes_reset_idx ON fetchq_catalog.fetchq_sys_metrics_writes ( queue, metric ) WHERE ( reset IS NOT NULL );
    CREATE INDEX IF NOT EXISTS fetchq_sys_metrics_writes_increment_idx ON fetchq_catalog.fetchq_sys_metrics_writes ( queue, metric ) WHERE ( increment IS NOT NULL );

    -- Maintenance Jobs
    CREATE TABLE IF NOT EXISTS fetchq_catalog.fetchq_sys_jobs (
        id SERIAL PRIMARY KEY,
        task character varying(40) NOT NULL,
        queue character varying(40) NOT NULL,
        attempts integer DEFAULT 0,
        iterations integer DEFAULT 0,
        next_iteration timestamp with time zone,
        last_iteration timestamp with time zone,
        settings jsonb,
        payload jsonb
    );

    -- CREATE SEQUENCE fetchq_sys_jobs_id_seq
    --     START WITH 1
    --     INCREMENT BY 1
    --     NO MINVALUE
    --     NO MAXVALUE
    --     CACHE 1;

    -- ALTER SEQUENCE fetchq_sys_jobs_id_seq OWNED BY fetchq_sys_jobs.id;
    -- ALTER TABLE ONLY fetchq_sys_jobs ALTER COLUMN id SET DEFAULT nextval('fetchq_sys_jobs_id_seq'::regclass);
    -- ALTER TABLE ONLY fetchq_sys_jobs ADD CONSTRAINT fetchq_sys_jobs_pkey PRIMARY KEY (id);
    CREATE UNIQUE INDEX IF NOT EXISTS fetchq_sys_jobs_task_queue_idx ON fetchq_catalog.fetchq_sys_jobs USING btree (task, queue);
    CREATE INDEX IF NOT EXISTS fetchq_sys_jobs_task_idx ON fetchq_catalog.fetchq_sys_jobs USING btree (task, next_iteration, iterations) WHERE (iterations < 5);

    -- add generic maintenance jobs
    INSERT INTO fetchq_catalog.fetchq_sys_jobs (task, queue, next_iteration, last_iteration, attempts, iterations, settings, payload) VALUES
	('lgp', '*', NOW(), NULL, 0, 0, '{"delay":"3s", "duration":"5m"}', '{}')
	ON CONFLICT DO NOTHING;
    
    -- handle output with graceful fail support
    EXCEPTION WHEN OTHERS THEN BEGIN
		was_initialized = FALSE;
	END;

END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_destroy_with_terrible_consequences();
CREATE OR REPLACE FUNCTION fetchq_destroy_with_terrible_consequences (
    OUT was_destroyed BOOLEAN
) AS $$
DECLARE
    VAR_q RECORD;
BEGIN
    DROP SCHEMA IF EXISTS fetchq_catalog CASCADE;

    -- drop all queues
    -- FOR VAR_q IN
	-- 	SELECT (name) FROM fetchq_catalog.fetchq_sys_queues
	-- LOOP
    --     PERFORM fetchq_queue_drop(VAR_q.name);
	-- END LOOP;

    -- Queues Index
    -- DROP TABLE fetchq_catalog.fetchq_sys_queues CASCADE;

    -- Metrics Overview
    -- DROP TABLE fetchq_catalog.fetchq_sys_metrics CASCADE;

    -- Metrics Writes
    -- DROP TABLE fetchq_catalog.fetchq_sys_metrics_writes CASCADE;

    -- Maintenance Jobs
    -- DROP TABLE fetchq_catalog.fetchq_sys_jobs CASCADE;

    -- handle output with graceful fail support
	-- was_destroyed = TRUE;
    -- EXCEPTION WHEN OTHERS THEN BEGIN
	-- 	was_destroyed = FALSE;
	-- END;

END; $$
LANGUAGE plpgsql;
DROP FUNCTION IF EXISTS fetchq_metric_set(CHARACTER VARYING, CHARACTER VARYING, INTEGER);
CREATE OR REPLACE FUNCTION fetchq_metric_set (
	PAR_queue VARCHAR,
	PAR_subject VARCHAR,
	PAR_value INTEGER,
	OUT current_value INTEGER,
	OUT was_created BOOLEAN
) AS $$
DECLARE
	updated_rows NUMERIC;
BEGIN
	was_created := false;
	current_value := 0;

	UPDATE fetchq_catalog.fetchq_sys_metrics
	SET value = PAR_value, updated_at = now()
	WHERE id IN (
		SELECT id FROM fetchq_catalog.fetchq_sys_metrics
		WHERE queue = PAR_queue
		AND metric = PAR_subject
		LIMIT 1
		FOR UPDATE
	)
	RETURNING value into current_value;
	GET DIAGNOSTICS updated_rows := ROW_COUNT;

	IF updated_rows = 0 THEN
		INSERT INTO fetchq_catalog.fetchq_sys_metrics
			(queue, metric, value, updated_at)
		VALUES
			(PAR_queue, PAR_subject, PAR_value, now())
		ON CONFLICT DO NOTHING
		RETURNING value into current_value;
		was_created := true;
	END IF;
END; $$
LANGUAGE plpgsql;DROP FUNCTION IF EXISTS fetchq_metric_increment(CHARACTER VARYING, CHARACTER VARYING, INTEGER);
CREATE OR REPLACE FUNCTION fetchq_metric_increment (
	PAR_queue VARCHAR,
	PAR_subject VARCHAR,
	PAR_value INTEGER,
	OUT current_value INTEGER,
	OUT was_created BOOLEAN
) AS $$
DECLARE
	updated_rows NUMERIC;
BEGIN
	was_created := false;
	current_value := 0;

	UPDATE fetchq_catalog.fetchq_sys_metrics
	SET value = value + PAR_value, updated_at = now()
	WHERE id IN (
		SELECT id FROM fetchq_catalog.fetchq_sys_metrics
		WHERE queue = PAR_queue
		AND metric = PAR_subject
		LIMIT 1
		FOR UPDATE
	)
	RETURNING value into current_value;
	GET DIAGNOSTICS updated_rows := ROW_COUNT;

	IF updated_rows = 0 THEN
		INSERT INTO fetchq_catalog.fetchq_sys_metrics
			(queue, metric, value, updated_at)
		VALUES
			(PAR_queue, PAR_subject, PAR_value, now())
		ON CONFLICT DO NOTHING
		RETURNING value into current_value;
		was_created := true;
	END IF;
END; $$
LANGUAGE plpgsql;DROP FUNCTION IF EXISTS fetchq_metric_log_set(CHARACTER VARYING, CHARACTER VARYING, INTEGER);
CREATE OR REPLACE FUNCTION fetchq_metric_log_set (
	PAR_queue VARCHAR,
	PAR_subject VARCHAR,
	PAR_value INTEGER,
	OUT affected_rows INTEGER
) AS $$
BEGIN
	INSERT INTO fetchq_catalog.fetchq_sys_metrics_writes
	( created_at, queue, metric, reset )
	VALUES
	( NOW(), PAR_queue, PAR_subject, PAR_value );
	GET DIAGNOSTICS affected_rows := ROW_COUNT;
END; $$
LANGUAGE plpgsql;
DROP FUNCTION IF EXISTS fetchq_metric_log_increment(CHARACTER VARYING, CHARACTER VARYING, INTEGER);
CREATE OR REPLACE FUNCTION fetchq_metric_log_increment (
	PAR_queue VARCHAR,
	PAR_subject VARCHAR,
	PAR_value INTEGER,
	OUT affected_rows INTEGER
) AS $$
BEGIN
	INSERT INTO fetchq_catalog.fetchq_sys_metrics_writes
	( created_at, queue, metric, increment )
	VALUES
	( NOW(), PAR_queue, PAR_subject, PAR_value );
	GET DIAGNOSTICS affected_rows := ROW_COUNT;
END; $$
LANGUAGE plpgsql;DROP FUNCTION IF EXISTS fetchq_metric_log_decrement(CHARACTER VARYING, CHARACTER VARYING, INTEGER);
CREATE OR REPLACE FUNCTION fetchq_metric_log_decrement (
	PAR_queue VARCHAR,
	PAR_subject VARCHAR,
	PAR_value INTEGER,
	OUT affected_rows INTEGER
) AS $$
BEGIN
	INSERT INTO fetchq_catalog.fetchq_sys_metrics_writes
	( created_at, queue, metric, increment )
	VALUES
	( NOW(), PAR_queue, PAR_subject, 0 - PAR_value );
	GET DIAGNOSTICS affected_rows := ROW_COUNT;
END; $$
LANGUAGE plpgsql;DROP FUNCTION IF EXISTS fetchq_metric_log_pack();
CREATE OR REPLACE FUNCTION fetchq_metric_log_pack (
	OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_r RECORD;
	VAR_sum INTEGER;
BEGIN

	-- fetch data to work on from the writes log
	CREATE TEMP TABLE fetchq_sys_metrics_writes_pack ON COMMIT DROP
	AS SELECT * FROM fetchq_catalog.fetchq_sys_metrics_writes WHERE created_at <= NOW();

	-- reset counters to current value
	FOR VAR_r IN
		SELECT DISTINCT ON (queue, metric) id, queue, metric, reset
		FROM fetchq_sys_metrics_writes_pack
		WHERE reset IS NOT NULL
		ORDER BY queue, metric, created_at DESC
	LOOP
		PERFORM fetchq_metric_set(VAR_r.queue, VAR_r.metric, VAR_r.reset::integer);
	END LOOP;

	-- aggregate the rest of increments
	FOR VAR_r IN
		SELECT DISTINCT ON (queue, metric) id, queue, metric, increment
		FROM fetchq_sys_metrics_writes_pack
		WHERE increment IS NOT NULL
		ORDER BY queue, metric, created_at ASC
	LOOP
		SELECT SUM(increment) INTO VAR_sum
		FROM fetchq_sys_metrics_writes_pack
		WHERE queue = VAR_r.queue
		AND metric = VAR_r.metric
		AND increment IS NOT NULL;

		PERFORM fetchq_metric_increment(VAR_r.queue, VAR_r.metric, VAR_sum);
	END LOOP;

	-- drop records that have been worked out
	DELETE FROM fetchq_catalog.fetchq_sys_metrics_writes WHERE id IN
	(SELECT id FROM fetchq_sys_metrics_writes_pack);
	GET DIAGNOSTICS affected_rows := ROW_COUNT;

	-- forcefully drop the temp table;
	DROP TABLE fetchq_sys_metrics_writes_pack;

END; $$
LANGUAGE plpgsql;
-- READS A SPECIFIC METRIC FOR A SPECIFIC QUEUE
DROP FUNCTION IF EXISTS fetchq_metric_get(CHARACTER VARYING, CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_metric_get (
	PAR_queue VARCHAR,
	PAR_subject VARCHAR,
	OUT current_value INTEGER,
	OUT last_update TIMESTAMP WITH TIME ZONE,
	OUT does_exists BOOLEAN
) AS $$
DECLARE
	VAR_r RECORD;
	VAR_rows INTEGER;
BEGIN
	SELECT * into VAR_r FROM fetchq_catalog.fetchq_sys_metrics
	WHERE queue = PAR_queue
	AND metric = PAR_subject
	LIMIT 1;
	
	GET DIAGNOSTICS VAR_rows := ROW_COUNT;

	IF VAR_rows > 0 THEN
		current_value = VAR_r.value;
		last_update = VAR_r.updated_at;
		does_exists = true;
	END IF;
	
	IF VAR_rows = 0 THEN
		current_value = 0;
		last_update = null;
		does_exists = false;
	END IF;	
	
--	raise log '%', VAR_r.updated_at;
END; $$
LANGUAGE plpgsql;

-- READS ALL AVAILABLE METRIC FOR A QUEUE
DROP FUNCTION IF EXISTS fetchq_metric_get(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_metric_get (
	PAR_queue VARCHAR
) RETURNS TABLE (
	metric VARCHAR,
	current_value BIGINT,
	last_update TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
	RETURN QUERY
	SELECT t.metric, t.value AS current_value, t.updated_at AS last_update
	FROM fetchq_catalog.fetchq_sys_metrics AS t
	WHERE queue = PAR_queue
	ORDER BY metric ASC;
END; $$
LANGUAGE plpgsql;

-- READS THE TOTAL OF A METRIC ACROSS ALL THE QUEUES
DROP FUNCTION IF EXISTS fetchq_metric_get_total(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_metric_get_total (
	PAR_metric VARCHAR,
	OUT current_value INTEGER,
	OUT does_exists BOOLEAN
) AS $$
BEGIN
	SELECT sum(value) INTO current_value
	FROM fetchq_sys_metrics
	WHERE metric = PAR_metric;

	does_exists = TRUE;
	IF current_value IS NULL THEN
		current_value = 0;
		does_exists = FALSE;
	END IF;
END; $$
LANGUAGE plpgsql;
-- GET ALL COMMOMN METRICS FOR A SPECIFIC QUEUE
DROP FUNCTION IF EXISTS fetchq_metric_get_common(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_metric_get_common(
	PAR_queue VARCHAR,
	OUT cnt INTEGER,
	OUT pnd INTEGER,
	OUT pln INTEGER,
	OUT act INTEGER,
	OUT cpl INTEGER,
	OUT kll INTEGER,
	OUT ent INTEGER,
	OUT drp INTEGER,
	OUT pkd INTEGER,
	OUT prc INTEGER,
	OUT res INTEGER,
	OUT rej INTEGER,
	OUT orp INTEGER,
	OUT err INTEGER
) AS
$BODY$
DECLARE
	VAR_q RECORD;
	VAR_c RECORD;
BEGIN
	FOR VAR_q IN
		SELECT * FROM fetchq_metric_get(PAR_queue)
	LOOP
		IF VAR_q.metric = 'cnt' THEN cnt = VAR_q.current_value; END IF;
		IF VAR_q.metric = 'pnd' THEN pnd = VAR_q.current_value; END IF;
		IF VAR_q.metric = 'pln' THEN pln = VAR_q.current_value; END IF;
		IF VAR_q.metric = 'act' THEN act = VAR_q.current_value; END IF;
		IF VAR_q.metric = 'cpl' THEN cpl = VAR_q.current_value; END IF;
		IF VAR_q.metric = 'kll' THEN kll = VAR_q.current_value; END IF;
		IF VAR_q.metric = 'ent' THEN ent = VAR_q.current_value; END IF;
		IF VAR_q.metric = 'drp' THEN drp = VAR_q.current_value; END IF;
		IF VAR_q.metric = 'pkd' THEN pkd = VAR_q.current_value; END IF;
		IF VAR_q.metric = 'prc' THEN prc = VAR_q.current_value; END IF;
		IF VAR_q.metric = 'res' THEN res = VAR_q.current_value; END IF;
		IF VAR_q.metric = 'rej' THEN rej = VAR_q.current_value; END IF;
		IF VAR_q.metric = 'orp' THEN orp = VAR_q.current_value; END IF;
		IF VAR_q.metric = 'err' THEN err = VAR_q.current_value; END IF;
	END LOOP;
END;
$BODY$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_metric_get_all();
CREATE OR REPLACE FUNCTION fetchq_metric_get_all() 
RETURNS TABLE (
	queue VARCHAR,
	cnt INTEGER,
	pnd INTEGER,
	pln INTEGER,
	act INTEGER,
	cpl INTEGER,
	kll INTEGER,
	ent INTEGER,
	drp INTEGER,
	pkd INTEGER,
	prc INTEGER,
	res INTEGER,
	rej INTEGER,
	orp INTEGER,
	err INTEGER
) AS
$BODY$
DECLARE
	VAR_q RECORD;
	VAR_c RECORD;
BEGIN
	FOR VAR_q IN
		SELECT (name) FROM fetchq_catalog.fetchq_sys_queues
	LOOP
		SELECT * FROM fetchq_metric_get_common(VAR_q.name) INTO VAR_c;
		queue = VAR_q.name;
		cnt = VAR_c.cnt;
		pnd = VAR_c.pnd;
		pln = VAR_c.pln;
		act = VAR_c.act;
		cpl = VAR_c.cpl;
		kll = VAR_c.kll;
		ent = VAR_c.ent;
		pkd = VAR_c.pkd;
		prc = VAR_c.prc;
		res = VAR_c.res;
		rej = VAR_c.rej;
		orp = VAR_c.orp;
		err = VAR_c.err;
		RETURN NEXT;
	END LOOP;
END;
$BODY$
LANGUAGE plpgsql;
-- SLOW QUERY!!!
-- calculates the real queue metrics by running real count(*) operations
-- on the target queue table:
-- select * from fetchq_metric_compute('is_prf');
--
-- NOTE: this is real slow query!
-- better put the entire system in pause before you run this one
DROP FUNCTION IF EXISTS fetchq_metric_compute(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_metric_compute (
	PAR_queue VARCHAR,
	OUT cnt INTEGER,
	OUT pln INTEGER,
	OUT pnd INTEGER,
	OUT act INTEGER,
	OUT kll INTEGER,
	OUT cpl INTEGER
) AS
$BODY$
DECLARE
	VAR_q1 CONSTANT VARCHAR := 'SELECT COUNT(subject) FROM fetchq__%s__documents';
	VAR_q2 CONSTANT VARCHAR := 'SELECT COUNT(subject) FROM fetchq__%s__documents WHERE STATUS = %s';
BEGIN
	cnt = 0;
	pln = 0;
	pnd = 0;
	act = 0;
	kll = 0;
	cpl = 0;
	
	EXECUTE FORMAT(VAR_q1, PAR_queue) INTO cnt;
	EXECUTE FORMAT(VAR_q2, PAR_queue, -1) INTO kll;
	EXECUTE FORMAT(VAR_q2, PAR_queue, 0) INTO pln;
	EXECUTE FORMAT(VAR_q2, PAR_queue, 1) INTO pnd;
	EXECUTE FORMAT(VAR_q2, PAR_queue, 3) INTO cpl;
END;
$BODY$
LANGUAGE plpgsql;
-- SLOW QUERY!!!
-- computes and shows fresh counters from all the queues
DROP FUNCTION IF EXISTS fetchq_metric_compute_all();
CREATE OR REPLACE FUNCTION fetchq_metric_compute_all () 
RETURNS TABLE (
	queue VARCHAR,
	cnt INTEGER,
	pln INTEGER,
	pnd INTEGER,
	act INTEGER,
    cpl INTEGER,
	kll INTEGER
) AS
$BODY$
DECLARE
	VAR_q RECORD;
	VAR_c RECORD;
BEGIN
	
	FOR VAR_q IN
		SELECT (name) FROM fetchq_catalog.fetchq_sys_queues
	LOOP
		SELECT * FROM fetchq_metric_compute(VAR_q.name) INTO VAR_c;
		queue = VAR_q.name;
		cnt = VAR_c.cnt;
		pln = VAR_c.pln;
		pnd = VAR_c.pnd;
		act = VAR_c.act;
        cpl = VAR_c.cpl;
		kll = VAR_c.kll;
		RETURN NEXT;
	END LOOP;
	
END;
$BODY$
LANGUAGE plpgsql;

-- SLOW QUERY!
-- compute and resets all the basic counters for a queue metrics
DROP FUNCTION IF EXISTS fetchq_metric_reset(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_metric_reset (
	PAR_queue VARCHAR,
	OUT cnt INTEGER,
	OUT pln INTEGER,
	OUT pnd INTEGER,
	OUT act INTEGER,
    OUT cpl INTEGER,
	OUT kll INTEGER
) AS
$BODY$
DECLARE
	VAR_res RECORD;
BEGIN
	SELECT * INTO VAR_res FROM fetchq_metric_compute(PAR_queue);
	
	PERFORM fetchq_metric_set(PAR_queue, 'cnt', VAR_res.cnt);
	PERFORM fetchq_metric_set(PAR_queue, 'pln', VAR_res.pln);
	PERFORM fetchq_metric_set(PAR_queue, 'pnd', VAR_res.pnd);
	PERFORM fetchq_metric_set(PAR_queue, 'act', VAR_res.act);
    PERFORM fetchq_metric_set(PAR_queue, 'cpl', VAR_res.cpl);
	PERFORM fetchq_metric_set(PAR_queue, 'kll', VAR_res.kll);
	
	-- forward data out
	cnt = VAR_res.cnt;
	pln = VAR_res.pln;
	pnd = VAR_res.pnd;
	act = VAR_res.act;
    cpl = VAR_res.cpl;
	kll = VAR_res.kll;

END;
$BODY$
LANGUAGE plpgsql;

-- SLOW QUERY!!!
-- computes and resets fresh counters from all the queries
DROP FUNCTION IF EXISTS fetchq_metric_reset_all();
CREATE OR REPLACE FUNCTION fetchq_metric_reset_all () 
RETURNS TABLE (
	queue VARCHAR,
	cnt INTEGER,
	pln INTEGER,
	pnd INTEGER,
	act INTEGER,
    cpl INTEGER,
	kll INTEGER
) AS
$BODY$
DECLARE
	VAR_q RECORD;
	VAR_c RECORD;
BEGIN
	FOR VAR_q IN
		SELECT (name) FROM fetchq_catalog.fetchq_sys_queues
	LOOP
		SELECT * FROM fetchq_metric_reset(VAR_q.name) INTO VAR_c;
		queue = VAR_q.name;
		cnt = VAR_c.cnt;
		pln = VAR_c.pln;
		pnd = VAR_c.pnd;
		act = VAR_c.act;
        cpl = VAR_c.cpl;
		kll = VAR_c.kll;
		RETURN NEXT;
	END LOOP;
END;
$BODY$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_metric_snap(CHARACTER VARYING, CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_metric_snap (
	PAR_queue VARCHAR,
	PAR_metric VARCHAR,
	OUT success BOOLEAN,
    OUT inserts INTEGER
) AS $$
DECLARE
    VAR_r RECORD;
    VAR_q VARCHAR;
BEGIN
	success = true;
    SELECT * INTO VAR_r FROM fetchq_metric_get(PAR_queue, PAR_metric);
    RAISE NOTICE '%', VAR_r.current_value;

    VAR_q = 'INSERT INTO fetchq_catalog.fetchq__%s__metrics ';
	VAR_q = VAR_q || '( metric,  value) VALUES ';
	VAR_q = VAR_q || '( ''%s'',  %s );';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_metric, VAR_r.current_value);
	EXECUTE VAR_q;
    GET DIAGNOSTICS inserts := ROW_COUNT;

    -- RAISE EXCEPTION 'foo';
    EXCEPTION WHEN OTHERS THEN BEGIN
        success = false;
    END;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_metric_snap(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_metric_snap (
	PAR_queue VARCHAR,
	OUT success BOOLEAN,
    OUT inserts INTEGER
) AS $$
DECLARE
    VAR_q VARCHAR;
BEGIN
	success = true;

    VAR_q = 'INSERT INTO fetchq_catalog.fetchq__%s__metrics ( metric,  value)';
	VAR_q = VAR_q || 'SELECT metric, current_value AS value ';
	VAR_q = VAR_q || 'FROM fetchq_metric_get(''%s'')';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue);
	EXECUTE VAR_q;
    GET DIAGNOSTICS inserts := ROW_COUNT;

    -- RAISE EXCEPTION 'foo';
    EXCEPTION WHEN OTHERS THEN BEGIN
        success = false;
    END;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_metric_snap(CHARACTER VARYING, JSONB);
CREATE OR REPLACE FUNCTION fetchq_metric_snap (
	PAR_queue VARCHAR,
    PAR_whiteList JSONB,
	OUT success BOOLEAN,
    OUT inserts INTEGER
) AS $$
DECLARE
    VAR_q VARCHAR;
    VAR_r RECORD;
BEGIN
	success = true;

    VAR_q = 'INSERT INTO fetchq_catalog.fetchq__%s__metrics ( metric,  value)';
	VAR_q = VAR_q || 'SELECT metric, current_value AS value ';
	VAR_q = VAR_q || 'FROM fetchq_metric_get(''%s'') AS metrics ';
	VAR_q = VAR_q || 'INNER JOIN (SELECT value::varchar FROM jsonb_array_elements_text(''%s'')) ';
	VAR_q = VAR_q || 'AS filters ON metrics.metric = filters.value;';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue, PAR_whiteList);
	EXECUTE VAR_q;
    GET DIAGNOSTICS inserts := ROW_COUNT;

    EXCEPTION WHEN OTHERS THEN BEGIN
        success = false;
    END;
END; $$
LANGUAGE plpgsql;
-- PUSH A SINGLE DOCUMENT
DROP FUNCTION IF EXISTS fetchq_doc_push(CHARACTER VARYING, CHARACTER VARYING, INTEGER, INTEGER, TIMESTAMP WITH TIME ZONE, JSONB);
CREATE OR REPLACE FUNCTION fetchq_doc_push (
    PAR_queue VARCHAR,
    PAR_subject VARCHAR,
    PAR_version INTEGER,
    PAR_priority INTEGER,
    PAR_nextIteration TIMESTAMP WITH TIME ZONE,
    PAR_payload JSONB,
    OUT queued_docs INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
    VAR_status INTEGER = 0;
BEGIN
    -- pick right status based on nextIteration date
    IF PAR_nextIteration <= NOW() THEN
		VAR_status = 1;
	END IF;

    -- push the document into the data table
    VAR_q = 'INSERT INTO fetchq_catalog.fetchq__%s__documents (';
	VAR_q = VAR_q || 'subject, version, priority, status, next_iteration, payload, created_at) VALUES (';
    VAR_q = VAR_q || '''%s'', ';
    VAR_q = VAR_q || '%s, ';
    VAR_q = VAR_q || '%s, ';
    VAR_q = VAR_q || '%s, ';
    VAR_q = VAR_q || '''%s'', ';
    VAR_q = VAR_q || '''%s'', ';
    VAR_q = VAR_q || 'NOW() ';
	VAR_q = VAR_q || ')';
    VAR_q = FORMAT(VAR_q, PAR_queue, PAR_subject, PAR_version, PAR_priority, VAR_status, PAR_nextIteration, PAR_payload);
    -- RAISE INFO '%', VAR_q;
    EXECUTE VAR_q;
    GET DIAGNOSTICS queued_docs := ROW_COUNT;

    -- update generic counters
	PERFORM fetchq_metric_log_increment(PAR_queue, 'ent', queued_docs);
	PERFORM fetchq_metric_log_increment(PAR_queue, 'cnt', queued_docs);

	-- upate version counter
	PERFORM fetchq_metric_log_increment(PAR_queue, 'v' || PAR_version::text, queued_docs);

    -- update status counter
	IF VAR_status = 1 THEN
		PERFORM fetchq_metric_log_increment(PAR_queue, 'pnd', queued_docs);

		-- emit worker notifications
		-- IF queued_docs > 0 THEN
		-- 	PERFORM pg_notify(FORMAT('fetchq_pnd_%s', PAR_queue), queued_docs::text);
		-- END IF;
	ELSE
		PERFORM fetchq_metric_log_increment(PAR_queue, 'pln', queued_docs);

		-- emit worker notifications
		-- IF queued_docs > 0 THEN
		-- 	PERFORM pg_notify(FORMAT('fetchq_pln_%s', PAR_queue), queued_docs::text);
		-- END IF;
	END IF;

    -- handle exception
	EXCEPTION WHEN OTHERS THEN BEGIN
		queued_docs = 0;
	END;
END; $$
LANGUAGE plpgsql;

-- PUSH MANY DOCUMENTS
DROP FUNCTION IF EXISTS fetchq_doc_push(CHARACTER VARYING, INTEGER, TIMESTAMP WITH TIME ZONE, CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_doc_push (
	PAR_queue VARCHAR,
	PAR_version INTEGER,
	PAR_nextIteration TIMESTAMP WITH TIME ZONE,
	PAR_data VARCHAR,
	OUT queued_docs INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
	VAR_status INTEGER = 0;
BEGIN
    -- pick right status based on nextIteration date
	IF PAR_nextIteration <= now() THEN
		VAR_status = 1;
	END IF;

    -- push the documents into the data table
	SELECT replace INTO PAR_data (PAR_data, '{DATA}', VAR_status::text || ', ' || PAR_version::text || ', ' || '''' || PAR_nextIteration::text || '''' || ', NULL, NOW()');
	VAR_q = 'INSERT INTO fetchq_catalog.fetchq__%s__documents (subject, priority, payload, status, version, next_iteration, lock_upgrade, created_at) VALUES %s ON CONFLICT DO NOTHING;';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_data);
	-- RAISE INFO '%', VAR_q;
	EXECUTE VAR_q;
	GET DIAGNOSTICS queued_docs := ROW_COUNT;

	-- update generic counters
	PERFORM fetchq_metric_log_increment(PAR_queue, 'ent', queued_docs);
	PERFORM fetchq_metric_log_increment(PAR_queue, 'cnt', queued_docs);

	-- upate version counter
	PERFORM fetchq_metric_log_increment(PAR_queue, 'v' || PAR_version::text, queued_docs);

    -- update status counter
	IF VAR_status = 1 THEN
		PERFORM fetchq_metric_log_increment(PAR_queue, 'pnd', queued_docs);

		-- emit worker notifications
		-- IF queued_docs > 0 THEN
		-- 	PERFORM pg_notify(FORMAT('fetchq_pnd_%s', PAR_queue), queued_docs::text);
		-- END IF;
	ELSE
		PERFORM fetchq_metric_log_increment(PAR_queue, 'pln', queued_docs);

        -- emit worker notifications
		-- IF queued_docs > 0 THEN
		-- 	PERFORM pg_notify(FORMAT('fetchq_pln_%s', PAR_queue), queued_docs::text);
		-- END IF;
	END IF;

	EXCEPTION WHEN OTHERS THEN BEGIN
		queued_docs = 0;
	END;
END; $$
LANGUAGE plpgsql;



-- APPEND A SINGLE DOCUMENT WITH A RANDOM GENERATED SUBJECT
-- DEPENDS ON uuid-ossp EXTENSION
-- (CREATE EXTENSION IF NOT EXISTS "uuid-ossp";)
DROP FUNCTION IF EXISTS fetchq_doc_append(CHARACTER VARYING, JSONB, INTEGER, INTEGER);
CREATE OR REPLACE FUNCTION fetchq_doc_append (
    PAR_queue VARCHAR,
    PAR_payload JSONB,
    PAR_version INTEGER,
    PAR_priority INTEGER,
    OUT subject VARCHAR
) AS $$
DECLARE
	VAR_q VARCHAR;
    VAR_queuedDocs INTEGER;
    VAR_subject VARCHAR;
    VAR_nextIteration TIMESTAMP WITH TIME ZONE = NOW();
    VAR_status INTEGER = 1;
BEGIN
    SELECT uuid_generate_v4 INTO VAR_subject from uuid_generate_v4();
    subject = VAR_subject;

    -- push the document into the data table
    VAR_q = 'INSERT INTO fetchq_catalog.fetchq__%s__documents (';
	VAR_q = VAR_q || 'subject, version, priority, status, next_iteration, payload, created_at) VALUES (';
    VAR_q = VAR_q || '''%s'', ';
    VAR_q = VAR_q || '%s, ';
    VAR_q = VAR_q || '%s, ';
    VAR_q = VAR_q || '%s, ';
    VAR_q = VAR_q || '''%s'', ';
    VAR_q = VAR_q || '''%s'', ';
    VAR_q = VAR_q || 'NOW() ';
	VAR_q = VAR_q || ')';
    VAR_q = FORMAT(VAR_q, PAR_queue, VAR_subject, PAR_version, PAR_priority, VAR_status, VAR_nextIteration, PAR_payload);
    -- RAISE INFO '%', VAR_q;
    EXECUTE VAR_q;
    GET DIAGNOSTICS VAR_queuedDocs := ROW_COUNT;

    -- update generic counters
	PERFORM fetchq_metric_log_increment(PAR_queue, 'ent', VAR_queuedDocs);
	PERFORM fetchq_metric_log_increment(PAR_queue, 'cnt', VAR_queuedDocs);

	-- upate version counter
	PERFORM fetchq_metric_log_increment(PAR_queue, 'v' || PAR_version::text, VAR_queuedDocs);

    -- update status counter
	IF VAR_status = 1 THEN
		PERFORM fetchq_metric_log_increment(PAR_queue, 'pnd', VAR_queuedDocs);

        -- emit worker notifications
		-- IF VAR_queuedDocs > 0 THEN
		-- 	PERFORM pg_notify(FORMAT('fetchq_pnd_%s', PAR_queue), VAR_queuedDocs::text);
		-- END IF;
	ELSE
		PERFORM fetchq_metric_log_increment(PAR_queue, 'pln', VAR_queuedDocs);

        -- emit worker notifications
		-- IF VAR_queuedDocs > 0 THEN
		-- 	PERFORM pg_notify(FORMAT('fetchq_pln_%s', PAR_queue), VAR_queuedDocs::text);
		-- END IF;
	END IF;

    -- handle exception
	EXCEPTION WHEN OTHERS THEN BEGIN
		VAR_queuedDocs = 0;
        subject = NULL;
	END;
END; $$
LANGUAGE plpgsql;
-- PUSH A SINGLE DOCUMENT
DROP FUNCTION IF EXISTS fetchq_doc_upsert(CHARACTER VARYING, CHARACTER VARYING, INTEGER, INTEGER, TIMESTAMP WITH TIME ZONE, JSONB);
CREATE OR REPLACE FUNCTION fetchq_doc_upsert (
    PAR_queue VARCHAR,
    PAR_subject VARCHAR,
    PAR_version INTEGER,
    PAR_priority INTEGER,
    PAR_nextIteration TIMESTAMP WITH TIME ZONE,
    PAR_payload JSONB,
    OUT queued_docs INTEGER,
    OUT updated_docs INTEGER
) AS $$
DECLARE
    VAR_r RECORD;
	VAR_q VARCHAR;
    VAR_status INTEGER = 0;
BEGIN
    queued_docs = 0;
    updated_docs = 0;

    SELECT * INTO VAR_r FROM fetchq_doc_push(PAR_queue, PAR_subject, PAR_version, PAR_priority, PAR_nextIteration, PAR_payload);
    queued_docs = VAR_r.queued_docs;

    RAISE NOTICE '>>>>>>>>> QUEUED DOCS %', queued_docs;

    IF queued_docs = 0 THEN
        VAR_q = '';
        VAR_q = VAR_q || 'UPDATE fetchq_catalog.fetchq__%s__documents SET ';
        VAR_q = VAR_q || 'priority = %s, ';
        VAR_q = VAR_q || 'payload = ''%s'', ';
        VAR_q = VAR_q || 'next_iteration = ''%s'' ';
        VAR_q = VAR_q || 'WHERE subject = ''%s'' AND lock_upgrade IS NULL AND status <> 2';
        VAR_q = FORMAT(VAR_q, PAR_queue, PAR_priority, PAR_payload, PAR_nextIteration, PAR_subject);

        EXECUTE VAR_q;
        GET DIAGNOSTICS updated_docs := ROW_COUNT;
    END IF;

    -- handle exception
	EXCEPTION WHEN OTHERS THEN BEGIN
		queued_docs = 0;
		updated_docs = 0;
	END;
END; $$
LANGUAGE plpgsql;-- PICK AND LOCK A DOCUMENT THAT NEEDS TO BE EXECUTED NEXT
-- returns:
-- { document_structure }
DROP FUNCTION IF EXISTS fetchq_doc_pick(CHARACTER VARYING, INTEGER, INTEGER, CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_doc_pick (
	PAR_queue VARCHAR,
	PAR_version INTEGER,
	PAR_limit INTEGER,
	PAR_duration VARCHAR
) RETURNS TABLE (
	subject VARCHAR,
	payload JSONB,
	version INTEGER,
	priority INTEGER,
	attempts INTEGER,
	iterations INTEGER,
	created_at TIMESTAMP WITH TIME ZONE,
	last_iteration TIMESTAMP WITH TIME ZONE,
	next_iteration TIMESTAMP WITH TIME ZONE,
	lock_upgrade TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
	VAR_tableName VARCHAR;
	VAR_tempTable VARCHAR;
	VAR_updateCtx VARCHAR;
	VAR_q VARCHAR;
	VAR_affectedRows INTEGER;
BEGIN
	-- get temporary table name
	VAR_tableName = FORMAT('fetchq_catalog.fetchq__%s__documents', PAR_queue);
	VAR_tempTable = FORMAT('fetchq__%s__pick_table', PAR_queue);
	VAR_updateCtx = FORMAT('fetchq__%s__pick_ctx', PAR_queue);

	-- create temporary table
	VAR_q = FORMAT('CREATE TEMP TABLE %s (subject VARCHAR(50)) ON COMMIT DROP;', VAR_tempTable);
	EXECUTE VAR_q;

	-- perform lock on the rows
	VAR_q = 'WITH %s AS ( ';
	VAR_q = VAR_q || 'UPDATE %s ';
	VAR_q = VAR_q || 'SET status = 2, next_iteration = NOW() + ''%s'', attempts = attempts + 1 ';
	VAR_q = VAR_q || 'WHERE subject IN ( SELECT subject FROM %s ';
    VAR_q = VAR_q || 'WHERE lock_upgrade IS NULL AND status = 1 AND version = %s AND next_iteration < NOW() ';
	VAR_q = VAR_q || 'ORDER BY priority DESC, next_iteration ASC, attempts ASC ';
	VAR_q = VAR_q || 'LIMIT %s FOR UPDATE SKIP LOCKED) RETURNING subject) ';
	VAR_q = VAR_q || 'INSERT INTO %s (subject) ';
	VAR_q = VAR_q || 'SELECT subject FROM %s; ';
	VAR_q = FORMAT(VAR_q, VAR_updateCtx, VAR_tableName, PAR_duration, VAR_tableName, PAR_version, PAR_limit, VAR_tempTable, VAR_updateCtx);
	EXECUTE VAR_q;
	GET DIAGNOSTICS VAR_affectedRows := ROW_COUNT;

	-- RAISE NOTICE 'attempt';
	-- RAISE NOTICE 'aff rows %', VAR_affectedRows;
	
	-- update counters
	PERFORM fetchq_metric_log_increment(PAR_queue, 'pkd', VAR_affectedRows);
	PERFORM fetchq_metric_log_increment(PAR_queue, 'act', VAR_affectedRows);
	PERFORM fetchq_metric_log_decrement(PAR_queue, 'pnd', VAR_affectedRows);

	-- return documents
	VAR_q = 'SELECT subject, payload, version, priority, attempts, iterations, created_at, last_iteration, next_iteration, lock_upgrade ';
	VAR_q = VAR_q || 'FROM %s WHERE subject IN ( SELECT subject ';
	VAR_q = VAR_q || 'FROM %s); ';
	VAR_q = FORMAT(VAR_q, VAR_tableName, VAR_tempTable);
	RETURN QUERY EXECUTE VAR_q;

	-- drop temporary table
	VAR_q = FORMAT('DROP TABLE %s;', VAR_tempTable);
	EXECUTE VAR_q;	

	EXCEPTION WHEN OTHERS THEN BEGIN END;
END; $$
LANGUAGE plpgsql;

-- RESCHEDULE AN ACTIVE DOCUMENT
-- returns:
-- { affected_rows: 1 }
DROP FUNCTION IF EXISTS fetchq_doc_reschedule(CHARACTER VARYING, CHARACTER VARYING, TIMESTAMP WITH TIME ZONE);
CREATE OR REPLACE FUNCTION fetchq_doc_reschedule (
	PAR_queue VARCHAR,
	PAR_subject VARCHAR,
	PAR_nextIteration TIMESTAMP WITH TIME ZONE,
	OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_tableName VARCHAR;
    VAR_lockName VARCHAR;
	VAR_q VARCHAR;
	VAR_iterations INTEGER;
BEGIN
	VAR_tableName = FORMAT('fetchq_catalog.fetchq__%s__documents', PAR_queue);
	VAR_lockName = FORMAT('fetchq_lock_queue_%s', PAR_queue);

	VAR_q = 'WITH %s AS ( ';
	VAR_q = VAR_q || 'UPDATE %s AS lc SET ';
	VAR_q = VAR_q || 'status = 0, next_iteration = ''%s'', attempts = 0, iterations = lc.iterations + 1, last_iteration = NOW() ';
	VAR_q = VAR_q || 'WHERE subject IN ( SELECT subject FROM %s WHERE subject = ''%s'' AND status = 2 LIMIT 1 ) RETURNING version) ';
	VAR_q = VAR_q || 'SELECT version FROM %s LIMIT 1;';
	VAR_q = FORMAT(VAR_q, VAR_lockName, VAR_tableName, PAR_nextIteration, VAR_tableName, PAR_subject, VAR_lockName);

--	raise log '%', VAR_q;

	EXECUTE VAR_q INTO VAR_iterations;
	GET DIAGNOSTICS affected_rows := ROW_COUNT;

	-- Update counters
	IF affected_rows > 0 THEN
		PERFORM fetchq_metric_log_increment(PAR_queue, 'prc', affected_rows);
		PERFORM fetchq_metric_log_increment(PAR_queue, 'res', affected_rows);
		PERFORM fetchq_metric_log_increment(PAR_queue, 'pln', affected_rows);
		PERFORM fetchq_metric_log_decrement(PAR_queue, 'act', affected_rows);
	END IF;

	-- raise log 'UPDATE %, DOMAIN %, VERSION %', affectedRows, domainId, versionNum;

--	EXCEPTION WHEN OTHERS THEN BEGIN END;
END; $$
LANGUAGE plpgsql;

-- RESCHEDULE AN ACTIVE DOCUMENT
-- returns:
-- { affected_rows: 1 }
DROP FUNCTION IF EXISTS fetchq_doc_reschedule(CHARACTER VARYING, CHARACTER VARYING, TIMESTAMP WITH TIME ZONE, JSONB);
CREATE OR REPLACE FUNCTION fetchq_doc_reschedule (
	PAR_queue VARCHAR,
	PAR_subject VARCHAR,
	PAR_nextIteration TIMESTAMP WITH TIME ZONE,
	PAR_payload JSONB,
	OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_tableName VARCHAR;
    VAR_lockName VARCHAR;
	VAR_q VARCHAR;
	VAR_iterations INTEGER;
BEGIN
	VAR_tableName = FORMAT('fetchq_catalog.fetchq__%s__documents', PAR_queue);
	VAR_lockName = FORMAT('fetchq_lock_queue_%s', PAR_queue);

	VAR_q = 'WITH %s AS ( ';
	VAR_q = VAR_q || 'UPDATE %s AS lc SET ';
	VAR_q = VAR_q || 'payload = ''%s'', status = 0, next_iteration = ''%s'', attempts = 0, iterations = lc.iterations + 1, last_iteration = NOW() ';
	VAR_q = VAR_q || 'WHERE subject IN ( SELECT subject FROM %s WHERE subject = ''%s'' AND status = 2 LIMIT 1 ) RETURNING version) ';
	VAR_q = VAR_q || 'SELECT version FROM %s LIMIT 1;';
	VAR_q = FORMAT(VAR_q, VAR_lockName, VAR_tableName, PAR_payload, PAR_nextIteration, VAR_tableName, PAR_subject, VAR_lockName);

--	raise log '%', VAR_q;

	EXECUTE VAR_q INTO VAR_iterations;
	GET DIAGNOSTICS affected_rows := ROW_COUNT;

	-- Update counters
	IF affected_rows > 0 THEN
		PERFORM fetchq_metric_log_increment(PAR_queue, 'prc', affected_rows);
		PERFORM fetchq_metric_log_increment(PAR_queue, 'res', affected_rows);
		PERFORM fetchq_metric_log_increment(PAR_queue, 'pln', affected_rows);
		PERFORM fetchq_metric_log_decrement(PAR_queue, 'act', affected_rows);
	END IF;

	-- raise log 'UPDATE %, DOMAIN %, VERSION %', affectedRows, domainId, versionNum;

--	EXCEPTION WHEN OTHERS THEN BEGIN END;
END; $$
LANGUAGE plpgsql;
-- @TODO: MAX ATTEMTS MUST COME FROM THE QUEUE

DROP FUNCTION IF EXISTS fetchq_doc_reject(CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING, JSONB);
CREATE OR REPLACE FUNCTION fetchq_doc_reject (
    PAR_queue VARCHAR,
    PAR_subject VARCHAR,
    PAR_message VARCHAR,
    PAR_details JSONB,
    OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
	VAR_r RECORD;
BEGIN
	-- get the current attempts limit
	VAR_q = '';
	VAR_q = VAR_q || 'SELECT max_attempts FROM fetchq_catalog.fetchq_sys_queues ';
	VAR_q = VAR_q || 'WHERE name = ''%s'' LIMIT 1';
	EXECUTE FORMAT(VAR_q, PAR_queue) INTO VAR_r;

	VAR_q = 'WITH fetchq_doc_reject_lock_%s AS ( UPDATE fetchq_catalog.fetchq__%s__documents AS lq SET ';
	VAR_q = VAR_q || 'status = CASE WHEN lq.attempts >= %s THEN -1 ELSE 1 END,';
	VAR_q = VAR_q || 'lock_upgrade = CASE WHEN lq.lock_upgrade IS NULL THEN NULL ELSE NOW() END,';
	VAR_q = VAR_q || 'iterations = lq.iterations + 1,';
	VAR_q = VAR_q || 'last_iteration = NOW() ';
	VAR_q = VAR_q || 'WHERE subject IN ( SELECT subject FROM fetchq_catalog.fetchq__%s__documents WHERE subject = ''%s'' AND status = 2 LIMIT 1) ';
    VAR_q = VAR_q || 'RETURNING version, status, subject) ';
	VAR_q = VAR_q || 'SELECT * FROM fetchq_doc_reject_lock_%s LIMIT 1; ';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue, VAR_r.max_attempts, PAR_queue, PAR_subject, PAR_queue);

	EXECUTE VAR_q INTO VAR_r;
	GET DIAGNOSTICS affected_rows := ROW_COUNT;

    -- RAISE NOTICE 'affetced rows %', affected_rows;
    -- RAISE NOTICE '%', VAR_r;

    IF affected_rows > 0 THEN
        -- log error
        PERFORM fetchq_log_error(PAR_queue, VAR_r.subject, PAR_message, PAR_details);

        -- update metrics
        PERFORM fetchq_metric_log_increment(PAR_queue, 'prc', 1);
        PERFORM fetchq_metric_log_increment(PAR_queue, 'err', 1);
		PERFORM fetchq_metric_log_increment(PAR_queue, 'rej', 1);
		PERFORM fetchq_metric_log_decrement(PAR_queue, 'act', 1);
		IF VAR_r.status = -1 THEN
			PERFORM fetchq_metric_log_increment(PAR_queue, 'kll', 1);
		ELSE
			PERFORM fetchq_metric_log_increment(PAR_queue, 'pnd', 1);
		END IF;
    END IF;

END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_doc_reject(CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING, JSONB, CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_doc_reject (
    PAR_queue VARCHAR,
    PAR_subject VARCHAR,
    PAR_message VARCHAR,
    PAR_details JSONB,
	PAR_refId VARCHAR,
    OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
	VAR_r RECORD;
BEGIN
	-- get the current attempts limit
	VAR_q = '';
	VAR_q = VAR_q || 'SELECT max_attempts FROM fetchq_catalog.fetchq_sys_queues ';
	VAR_q = VAR_q || 'WHERE name = ''%s'' LIMIT 1';
	EXECUTE FORMAT(VAR_q, PAR_queue) INTO VAR_r;

	VAR_q = 'WITH fetchq_doc_reject_lock_%s AS ( UPDATE fetchq_catalog.fetchq__%s__documents AS lq SET ';
	VAR_q = VAR_q || 'status = CASE WHEN lq.attempts >= %s THEN -1 ELSE 1 END,';
	VAR_q = VAR_q || 'lock_upgrade = CASE WHEN lq.lock_upgrade IS NULL THEN NULL ELSE NOW() END,';
	VAR_q = VAR_q || 'iterations = lq.iterations + 1,';
	VAR_q = VAR_q || 'last_iteration = NOW() ';
	VAR_q = VAR_q || 'WHERE subject IN ( SELECT subject FROM fetchq_catalog.fetchq__%s__documents WHERE subject = ''%s'' AND status = 2 LIMIT 1) ';
    VAR_q = VAR_q || 'RETURNING version, status, subject) ';
	VAR_q = VAR_q || 'SELECT * FROM fetchq_doc_reject_lock_%s LIMIT 1; ';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue, VAR_r.max_attempts, PAR_queue, PAR_subject, PAR_queue);

	EXECUTE VAR_q INTO VAR_r;
	GET DIAGNOSTICS affected_rows := ROW_COUNT;

    -- RAISE NOTICE 'affetced rows %', affected_rows;
    -- RAISE NOTICE '%', VAR_r;

    IF affected_rows > 0 THEN
        -- log error
        PERFORM fetchq_log_error(PAR_queue, VAR_r.subject, PAR_message, PAR_details, PAR_refId);

        -- update metrics
        PERFORM fetchq_metric_log_increment(PAR_queue, 'prc', 1);
        PERFORM fetchq_metric_log_increment(PAR_queue, 'err', 1);
		PERFORM fetchq_metric_log_increment(PAR_queue, 'rej', 1);
		PERFORM fetchq_metric_log_decrement(PAR_queue, 'act', 1);
		IF VAR_r.status = -1 THEN
			PERFORM fetchq_metric_log_increment(PAR_queue, 'kll', 1);
		ELSE
			PERFORM fetchq_metric_log_increment(PAR_queue, 'pnd', 1);
		END IF;
    END IF;

END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_doc_complete(CHARACTER VARYING, CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_doc_complete (
	PAR_queue VARCHAR,
	PAR_subject VARCHAR,
	OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_table_name VARCHAR = 'fetchq_';
	VAR_q VARCHAR;
BEGIN
	VAR_q = 'WITH fetchq_doc_complete_lock_%s AS ( ';
	VAR_q = VAR_q || 'UPDATE fetchq_catalog.fetchq__%s__documents AS lc SET ';
    VAR_q = VAR_q || 'status = 3,';
    VAR_q = VAR_q || 'attempts = 0,';
    VAR_q = VAR_q || 'iterations = lc.iterations + 1,';
    VAR_q = VAR_q || 'last_iteration = NOW(),';
    VAR_q = VAR_q || 'next_iteration = ''2970-01-01 00:00:00+00'' ';
	VAR_q = VAR_q || 'WHERE subject IN ( SELECT subject FROM fetchq_catalog.fetchq__%s__documents WHERE subject = ''%s'' AND status = 2 LIMIT 1 ) RETURNING version) ';
	VAR_q = VAR_q || 'SELECT version FROM fetchq_doc_complete_lock_%s LIMIT 1;';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue, PAR_queue, PAR_subject, PAR_queue);

	EXECUTE VAR_q;
	GET DIAGNOSTICS affected_rows := ROW_COUNT;

	-- Update counters
	IF affected_rows > 0 THEN
		PERFORM fetchq_metric_log_increment(PAR_queue, 'prc', affected_rows);
		PERFORM fetchq_metric_log_increment(PAR_queue, 'cpl', affected_rows);
		PERFORM fetchq_metric_log_decrement(PAR_queue, 'act', affected_rows);
	END IF;

	EXCEPTION WHEN OTHERS THEN BEGIN END;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_doc_complete(CHARACTER VARYING, CHARACTER VARYING, JSONB);
CREATE OR REPLACE FUNCTION fetchq_doc_complete (
	PAR_queue VARCHAR,
	PAR_subject VARCHAR,
	PAR_payload JSONB,
	OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_table_name VARCHAR = 'fetchq_';
	VAR_q VARCHAR;
BEGIN
	VAR_q = 'WITH fetchq_doc_complete_lock_%s AS ( ';
	VAR_q = VAR_q || 'UPDATE fetchq_catalog.fetchq__%s__documents AS lc SET ';
	VAR_q = VAR_q || 'payload = ''%s'',';
    VAR_q = VAR_q || 'status = 3,';
    VAR_q = VAR_q || 'attempts = 0,';
    VAR_q = VAR_q || 'iterations = lc.iterations + 1,';
    VAR_q = VAR_q || 'last_iteration = NOW(),';
    VAR_q = VAR_q || 'next_iteration = ''2970-01-01 00:00:00+00'' ';
	VAR_q = VAR_q || 'WHERE subject IN ( SELECT subject FROM fetchq_catalog.fetchq__%s__documents WHERE subject = ''%s'' AND status = 2 LIMIT 1 ) RETURNING version) ';
	VAR_q = VAR_q || 'SELECT version FROM fetchq_doc_complete_lock_%s LIMIT 1;';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue, PAR_payload, PAR_queue, PAR_subject, PAR_queue);

	EXECUTE VAR_q;
	GET DIAGNOSTICS affected_rows := ROW_COUNT;

	-- Update counters
	IF affected_rows > 0 THEN
		PERFORM fetchq_metric_log_increment(PAR_queue, 'prc', affected_rows);
		PERFORM fetchq_metric_log_increment(PAR_queue, 'cpl', affected_rows);
		PERFORM fetchq_metric_log_decrement(PAR_queue, 'act', affected_rows);
	END IF;

	EXCEPTION WHEN OTHERS THEN BEGIN END;
END; $$
LANGUAGE plpgsql;
DROP FUNCTION IF EXISTS fetchq_doc_kill(CHARACTER VARYING, CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_doc_kill (
	PAR_queue VARCHAR,
	PAR_subject VARCHAR,
	OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_table_name VARCHAR = 'fetchq_';
	VAR_q VARCHAR;
BEGIN
	VAR_q = 'WITH fetchq_doc_kill_lock_%s AS ( ';
	VAR_q = VAR_q || 'UPDATE fetchq_catalog.fetchq__%s__documents AS lc SET ';
    VAR_q = VAR_q || 'status = -1,';
    VAR_q = VAR_q || 'attempts = 0,';
    VAR_q = VAR_q || 'iterations = lc.iterations + 1,';
    VAR_q = VAR_q || 'last_iteration = NOW()';
	VAR_q = VAR_q || 'WHERE subject IN ( SELECT subject FROM fetchq_catalog.fetchq__%s__documents WHERE subject = ''%s'' AND status = 2 LIMIT 1 ) RETURNING version) ';
	VAR_q = VAR_q || 'SELECT version FROM fetchq_doc_kill_lock_%s LIMIT 1;';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue, PAR_queue, PAR_subject, PAR_queue);

	EXECUTE VAR_q;
	GET DIAGNOSTICS affected_rows := ROW_COUNT;

	-- Update counters
	IF affected_rows > 0 THEN
		PERFORM fetchq_metric_log_increment(PAR_queue, 'prc', affected_rows);
		PERFORM fetchq_metric_log_increment(PAR_queue, 'kll', affected_rows);
		PERFORM fetchq_metric_log_decrement(PAR_queue, 'act', affected_rows);
	END IF;

	EXCEPTION WHEN OTHERS THEN BEGIN END;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_doc_kill(CHARACTER VARYING, CHARACTER VARYING, JSONB);
CREATE OR REPLACE FUNCTION fetchq_doc_kill (
	PAR_queue VARCHAR,
	PAR_subject VARCHAR,
	PAR_payload JSONB,
	OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_table_name VARCHAR = 'fetchq_';
	VAR_q VARCHAR;
BEGIN
	VAR_q = 'WITH fetchq_doc_kill_lock_%s AS ( ';
	VAR_q = VAR_q || 'UPDATE fetchq_catalog.fetchq__%s__documents AS lc SET ';
	VAR_q = VAR_q || 'payload = ''%s'',';
    VAR_q = VAR_q || 'status = -1,';
    VAR_q = VAR_q || 'attempts = 0,';
    VAR_q = VAR_q || 'iterations = lc.iterations + 1,';
    VAR_q = VAR_q || 'last_iteration = NOW()';
	VAR_q = VAR_q || 'WHERE subject IN ( SELECT subject FROM fetchq_catalog.fetchq__%s__documents WHERE subject = ''%s'' AND status = 2 LIMIT 1 ) RETURNING version) ';
	VAR_q = VAR_q || 'SELECT version FROM fetchq_doc_kill_lock_%s LIMIT 1;';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue, PAR_payload, PAR_queue, PAR_subject, PAR_queue);

	EXECUTE VAR_q;
	GET DIAGNOSTICS affected_rows := ROW_COUNT;

	-- Update counters
	IF affected_rows > 0 THEN
		PERFORM fetchq_metric_log_increment(PAR_queue, 'prc', affected_rows);
		PERFORM fetchq_metric_log_increment(PAR_queue, 'kll', affected_rows);
		PERFORM fetchq_metric_log_decrement(PAR_queue, 'act', affected_rows);
	END IF;

	EXCEPTION WHEN OTHERS THEN BEGIN END;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_doc_drop(CHARACTER VARYING, CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_doc_drop (
	PAR_queue VARCHAR,
	PAR_subject VARCHAR,
	OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
	VAR_version INTEGER;
BEGIN

	VAR_q = 'DELETE FROM fetchq_catalog.fetchq__%s__documents WHERE subject = ''%s'' AND status = 2 RETURNING version;';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_subject);

	EXECUTE VAR_q INTO VAR_version;
	GET DIAGNOSTICS affected_rows := ROW_COUNT;
	-- raise log '% %', VAR_version, affected_rows;

	-- Update counters
	IF affected_rows > 0 THEN
		PERFORM fetchq_metric_log_increment(PAR_queue, 'prc', affected_rows);
		PERFORM fetchq_metric_log_increment(PAR_queue, 'drp', affected_rows);
		PERFORM fetchq_metric_log_decrement(PAR_queue, 'act', affected_rows);
		PERFORM fetchq_metric_log_decrement(PAR_queue, 'cnt', affected_rows);
		PERFORM fetchq_metric_log_decrement(PAR_queue, 'v' || VAR_version::text, affected_rows);
	END IF;

--	EXCEPTION WHEN OTHERS THEN BEGIN END;
END; $$
LANGUAGE plpgsql;
-- MAINTENANCE // CREATE PENDINGS
-- returns:
-- { affected_rows: 1 }
DROP FUNCTION IF EXISTS fetchq_mnt_make_pending(CHARACTER VARYING, INTEGER);
CREATE OR REPLACE FUNCTION fetchq_mnt_make_pending (
	PAR_queue VARCHAR,
	PAR_limit INTEGER,
	OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
BEGIN
    VAR_q = '';
	VAR_q = VAR_q || 'UPDATE fetchq_catalog.fetchq__%s__documents SET status = 1 ';
	VAR_q = VAR_q || 'WHERE subject IN ( ';
	VAR_q = VAR_q || 'SELECT subject FROM fetchq_catalog.fetchq__%s__documents ';
	VAR_q = VAR_q || 'WHERE lock_upgrade IS NULL AND status = 0 AND next_iteration < NOW() ';
	VAR_q = VAR_q || 'ORDER BY next_iteration ASC, attempts ASC ';
	VAR_q = VAR_q || 'LIMIT %s  ';
	VAR_q = VAR_q || 'FOR UPDATE); ';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue, PAR_limit);

	-- RAISE NOTICE '%', VAR_q;

	EXECUTE VAR_q;
	GET DIAGNOSTICS affected_rows := ROW_COUNT;

    -- RAISE NOTICE '%', affected_rows;

	PERFORM fetchq_metric_log_increment(PAR_queue, 'pnd', affected_rows);
	PERFORM fetchq_metric_log_decrement(PAR_queue, 'pln', affected_rows);

	-- emit worker notifications
	-- IF affected_rows > 0 THEN
	-- 	PERFORM pg_notify(FORMAT('fetchq_pnd_%s', PAR_queue), affected_rows::text);
	-- END IF;

	-- EXCEPTION WHEN OTHERS THEN BEGIN
	-- 	affected_rows = NULL;
	-- END;
END; $$
LANGUAGE plpgsql;
-- MAINTENANCE // RESCHEDULE ORPHANS
-- returns:
-- { affected_rows: 1 }
DROP FUNCTION IF EXISTS fetchq_mnt_reschedule_orphans(CHARACTER VARYING, INTEGER);
CREATE OR REPLACE FUNCTION fetchq_mnt_reschedule_orphans (
	PAR_queue VARCHAR,
	PAR_limit INTEGER,
	OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
	VAR_r RECORD;
BEGIN
	-- get the current attempts limit
	VAR_q = '';
	VAR_q = VAR_q || 'SELECT max_attempts FROM fetchq_catalog.fetchq_sys_queues ';
	VAR_q = VAR_q || 'WHERE name = ''%s'' LIMIT 1';
	EXECUTE FORMAT(VAR_q, PAR_queue) INTO VAR_r;

	VAR_q = '';
	VAR_q = VAR_q || 'UPDATE fetchq_catalog.fetchq__%s__documents SET status = 1 ';
	VAR_q = VAR_q || 'WHERE subject IN ( SELECT subject FROM fetchq_catalog.fetchq__%s__documents ';
	VAR_q = VAR_q || 'WHERE lock_upgrade IS NULL AND status = 2 AND attempts < %s AND next_iteration < NOW() ';
	VAR_q = VAR_q || 'LIMIT %s FOR UPDATE );';
	EXECUTE FORMAT(VAR_q, PAR_queue, PAR_queue, VAR_r.max_attempts, PAR_limit);
	GET DIAGNOSTICS affected_rows := ROW_COUNT;

	PERFORM fetchq_metric_log_increment(PAR_queue, 'err', affected_rows);
	PERFORM fetchq_metric_log_increment(PAR_queue, 'orp', affected_rows);
	PERFORM fetchq_metric_log_increment(PAR_queue, 'pnd', affected_rows);
	PERFORM fetchq_metric_log_decrement(PAR_queue, 'act', affected_rows);

	-- emit worker notifications
	-- IF affected_rows > 0 THEN
	-- 	PERFORM pg_notify(FORMAT('fetchq_pnd_%s', PAR_queue), affected_rows::text);
	-- END IF;

	EXCEPTION WHEN OTHERS THEN BEGIN
		affected_rows = NULL;
	END;
END; $$
LANGUAGE plpgsql;DROP FUNCTION IF EXISTS fetchq_mnt_mark_dead(CHARACTER VARYING, INTEGER);
CREATE OR REPLACE FUNCTION fetchq_mnt_mark_dead (
	PAR_queue VARCHAR,
	PAR_limit INTEGER,
	OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
	VAR_r RECORD;
BEGIN
	-- get the current attempts limit
	VAR_q = '';
	VAR_q = VAR_q || 'SELECT max_attempts FROM fetchq_catalog.fetchq_sys_queues ';
	VAR_q = VAR_q || 'WHERE name = ''%s'' LIMIT 1';
	EXECUTE FORMAT(VAR_q, PAR_queue) INTO VAR_r;

	VAR_q = '';
	VAR_q = VAR_q || 'UPDATE fetchq_catalog.fetchq__%s__documents SET status = -1 ';
	VAR_q = VAR_q || 'WHERE subject IN ( SELECT subject FROM fetchq_catalog.fetchq__%s__documents ';
	VAR_q = VAR_q || 'WHERE lock_upgrade IS NULL AND status = 2 AND attempts >= %s AND next_iteration < NOW() ';
	VAR_q = VAR_q || 'LIMIT %s FOR UPDATE );';
	EXECUTE FORMAT(VAR_q, PAR_queue, PAR_queue, VAR_r.max_attempts, PAR_limit);
	GET DIAGNOSTICS affected_rows := ROW_COUNT;

	PERFORM fetchq_metric_log_increment(PAR_queue, 'err', affected_rows);
	PERFORM fetchq_metric_log_increment(PAR_queue, 'orp', affected_rows);
	PERFORM fetchq_metric_log_increment(PAR_queue, 'kll', affected_rows);
	PERFORM fetchq_metric_log_decrement(PAR_queue, 'act', affected_rows);

	EXCEPTION WHEN OTHERS THEN BEGIN
		affected_rows = NULL;
	END;
END; $$
LANGUAGE plpgsql;-- MAINTENANCE // WRAPPER FUNCTION
-- returns:
-- { activated_count: 1, rescheduled_count: 1, killed_count: 1 }
DROP FUNCTION IF EXISTS fetchq_mnt_run(CHARACTER VARYING, INTEGER);
CREATE OR REPLACE FUNCTION fetchq_mnt_run (
	PAR_queue VARCHAR,
	PAR_limit INTEGER,
	OUT activated_count INTEGER,
	OUT rescheduled_count INTEGER,
	OUT killed_count INTEGER
) AS $$
BEGIN
	SELECT t.affected_rows INTO killed_count FROM fetchq_mnt_mark_dead(PAR_queue, PAR_limit) AS t;
	SELECT t.affected_rows INTO rescheduled_count FROM fetchq_mnt_reschedule_orphans(PAR_queue, PAR_limit) AS t;
	SELECT t.affected_rows INTO activated_count FROM fetchq_mnt_make_pending(PAR_queue, PAR_limit) AS t;
END; $$
LANGUAGE plpgsql;


-- MAINTENANCE FUNCTION
-- run maintenance wrapper for all the registered queues
DROP FUNCTION IF EXISTS fetchq_mnt_run_all(INTEGER);
CREATE OR REPLACE FUNCTION fetchq_mnt_run_all(
	PAR_limit INTEGER
) 
RETURNS TABLE (
	queue VARCHAR,
	activated_count INTEGER,
	rescheduled_count INTEGER,
	killed_count INTEGER
) AS
$BODY$
DECLARE
	VAR_q RECORD;
	VAR_c RECORD;
BEGIN
	FOR VAR_q IN
		SELECT (name) FROM fetchq_catalog.fetchq_sys_queues
	LOOP
		SELECT * FROM fetchq_mnt_run(VAR_q.name, PAR_limit) INTO VAR_c;
		queue = VAR_q.name;
		activated_count = VAR_c.activated_count;
		rescheduled_count = VAR_c.rescheduled_count;
		killed_count = VAR_c.killed_count;
		RETURN NEXT;
	END LOOP;
END;
$BODY$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_mnt_job_pick(CHARACTER VARYING, INTEGER);
CREATE OR REPLACE FUNCTION fetchq_mnt_job_pick (
	PAR_lockDuration VARCHAR,
    PAR_limit INTEGER
) RETURNS TABLE (
	id INTEGER,
    task VARCHAR,
    queue VARCHAR,
    attempts INTEGER,
    iterations INTEGER,
    next_iteration TIMESTAMP WITH TIME ZONE,
    last_iteration TIMESTAMP WITH TIME ZONE,
    settings JSONB,
    payload JSONB
) AS $$
DECLARE
	VAR_q VARCHAR;
BEGIN
    VAR_q = '';
    VAR_q = VAR_q || 'UPDATE fetchq_catalog.fetchq_sys_jobs SET ';
    VAR_q = VAR_q || 'next_iteration = NOW() + ''%s'', ';
    VAR_q = VAR_q || 'attempts = attempts + 1 ';
    VAR_q = VAR_q || 'WHERE id IN (SELECT id FROM fetchq_catalog.fetchq_sys_jobs WHERE attempts < 5 AND next_iteration < NOW() ORDER BY next_iteration ASC, attempts ASC LIMIT %s FOR UPDATE SKIP LOCKED) ';
    VAR_q = VAR_q || 'RETURNING *;';
    VAR_q = FORMAT(VAR_q, PAR_lockDuration, PAR_limit);
    -- RAISE NOTICE '%', VAR_q;
    RETURN QUERY EXECUTE VAR_q;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_mnt_job_reschedule(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_mnt_job_reschedule (
	PAR_id INTEGER,
    PAR_delay VARCHAR,
    OUT success BOOLEAN
) AS $$
DECLARE
	VAR_q VARCHAR;
BEGIN
    success = true;

    VAR_q = '';
    VAR_q = VAR_q || 'UPDATE fetchq_catalog.fetchq_sys_jobs SET ';
    VAR_q = VAR_q || 'next_iteration = NOW() + ''%s'', ';
    VAR_q = VAR_q || 'iterations = iterations + 1, ';
    VAR_q = VAR_q || 'attempts = 0 ';
    VAR_q = VAR_q || 'WHERE id = %s;';
    VAR_q = FORMAT(VAR_q, PAR_delay, PAR_id);
    EXECUTE VAR_q;

    EXCEPTION WHEN OTHERS THEN BEGIN
        success = false;
    END;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_mnt_job_run(CHARACTER VARYING, INTEGER);
CREATE OR REPLACE FUNCTION fetchq_mnt_job_run (
    PAR_lockDuration VARCHAR,
	PAR_limit INTEGER,
    OUT success BOOLEAN,
    OUT processed INTEGER
) AS $$
DECLARE
    VAR_r RECORD;
	VAR_q VARCHAR;
    VAR_limit INTEGER;
    VAR_delay VARCHAR;
BEGIN
    success = true;
    processed = 0;

    FOR VAR_r IN
		SELECT 
            id, task, queue, 
            settings->'limit' as limit_records, 
            settings->'delay' as execution_delay,
            settings->'duration' as execution_duration
        FROM fetchq_mnt_job_pick(PAR_lockDuration, PAR_limit)
	LOOP
        -- RAISE NOTICE '###########################';
		-- RAISE NOTICE '%', VAR_r;

        -- default records limit & next execution delay
        IF VAR_r.limit_records IS NOT NULL THEN VAR_limit = VAR_r.limit_records; ELSE VAR_limit = 100; END IF;
        IF VAR_r.execution_delay IS NOT NULL THEN VAR_delay = VAR_r.execution_delay; ELSE VAR_delay = '5m'; END IF;

        -- set custom lock duration fro job's settings
        IF VAR_r.execution_duration IS NOT NULL THEN
            VAR_q = '';
            VAR_q = VAR_q || 'UPDATE fetchq_catalog.fetchq_sys_jobs ';
            VAR_q = VAR_q || 'SET next_iteration = NOW() + INTERVAL ''%s'' ';
            VAR_q = VAR_q || 'WHERE id = %s;';
            VAR_q = FORMAT(VAR_q, VAR_r.execution_duration, VAR_r.id);
            EXECUTE VAR_q;
        END IF;

        -- run the specific task logic
        CASE
        WHEN VAR_r.task = 'lgp' THEN
            PERFORM fetchq_metric_log_pack();
        WHEN VAR_r.task = 'mnt' THEN
            PERFORM fetchq_mnt_run(VAR_r.queue, VAR_limit);
        WHEN VAR_r.task = 'drp' THEN
            PERFORM fetchq_queue_drop_metrics(VAR_r.queue);
            PERFORM fetchq_queue_drop_errors(VAR_r.queue);
        WHEN VAR_r.task = 'sts' THEN
            PERFORM fetchq_metric_snap(VAR_r.queue);
        ELSE
            RAISE NOTICE 'DONT KNOW TASK %', VAR_r.task;
        END CASE;

        -- reschedule job
        PERFORM fetchq_mnt_job_reschedule(VAR_r.id, VAR_delay);
        processed = processed + 1;
	END LOOP;

    EXCEPTION WHEN OTHERS THEN BEGIN
        success = false;
    END;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_mnt_job_run(INTEGER);
CREATE OR REPLACE FUNCTION fetchq_mnt_job_run (
	PAR_limit INTEGER,
    OUT success BOOLEAN,
    OUT processed INTEGER
) AS $$
DECLARE
    VAR_r RECORD;
	VAR_q VARCHAR;
    VAR_limit INTEGER;
    VAR_delay VARCHAR;
BEGIN
    SELECT * INTO VAR_r FROM fetchq_mnt_job_run('5m', PAR_limit) as t;
    success = VAR_r.success;
    processed = VAR_r.processed;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_mnt_job_run();
CREATE OR REPLACE FUNCTION fetchq_mnt_job_run (
    OUT success BOOLEAN,
    OUT processed INTEGER
) AS $$
DECLARE
    VAR_r RECORD;
	VAR_q VARCHAR;
    VAR_limit INTEGER;
    VAR_delay VARCHAR;
BEGIN
    SELECT * INTO VAR_r FROM fetchq_mnt_job_run(1) as t;
    success = VAR_r.success;
    processed = VAR_r.processed;
END; $$
LANGUAGE plpgsql;
DROP FUNCTION IF EXISTS fetchq_mnt(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_mnt (
    PAR_lockDuration VARCHAR,
	OUT processed INTEGER,
	OUT packed INTEGER
) AS $$
DECLARE
    VAR_countJobs INTEGER;
    VAR_r RECORD;
BEGIN
    -- set all the jobs to be executed
    -- (skip generic jobs)
    UPDATE fetchq_catalog.fetchq_sys_jobs SET next_iteration = NOW() - INTERVAL '1ms'
    WHERE queue != '*';

    -- run all the available jobs
    GET DIAGNOSTICS VAR_countJobs := ROW_COUNT;
    SELECT * INTO VAR_r FROM fetchq_mnt_job_run(PAR_lockDuration, VAR_countJobs);
	processed = VAR_r.processed;

    -- pack the generated metrics
    SELECT affected_rows INTO packed FROM fetchq_metric_log_pack();
    -- RAISE NOTICE 'packed = %', packed;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_mnt();
CREATE OR REPLACE FUNCTION fetchq_mnt (
	OUT processed INTEGER,
	OUT packed INTEGER
) AS $$
DECLARE
    VAR_r RECORD;
BEGIN
    SELECT * INTO VAR_r FROM fetchq_mnt('5m');
    processed = VAR_r.processed;
    packed = VAR_r.packed;
END; $$
LANGUAGE plpgsql;
DROP FUNCTION IF EXISTS fetchq_log_error(CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING, JSONB);
CREATE OR REPLACE FUNCTION fetchq_log_error (
    PAR_queue VARCHAR,
    PAR_subject VARCHAR,
    PAR_message VARCHAR,
    PAR_details JSONB,
    OUT queued_logs BOOLEAN
) AS $$
DECLARE
    VAR_q VARCHAR;
BEGIN

    VAR_q = 'INSERT INTO fetchq_catalog.fetchq__%s__errors (';
	VAR_q = VAR_q || 'created_at, subject, message, details';
    VAR_q = VAR_q || ') VALUES (';
    VAR_q = VAR_q || 'NOW(), ';
    VAR_q = VAR_q || '''%s'', ';
    VAR_q = VAR_q || '''%s'', ';
    VAR_q = VAR_q || '''%s'' ';
	VAR_q = VAR_q || ')';
    VAR_q = FORMAT(VAR_q, PAR_queue, PAR_subject, PAR_message, PAR_details);

    EXECUTE VAR_q;
    GET DIAGNOSTICS queued_logs := ROW_COUNT;

    -- handle exception
	EXCEPTION WHEN OTHERS THEN BEGIN
		queued_logs = 0;
	END;
END; $$
LANGUAGE plpgsql;


DROP FUNCTION IF EXISTS fetchq_log_error(CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING, JSONB, VARCHAR);
CREATE OR REPLACE FUNCTION fetchq_log_error (
    PAR_queue VARCHAR,
    PAR_subject VARCHAR,
    PAR_message VARCHAR,
    PAR_details JSONB,
    PAR_refId VARCHAR,
    OUT queued_logs BOOLEAN
) AS $$
DECLARE
    VAR_q VARCHAR;
BEGIN

    VAR_q = 'INSERT INTO fetchq_catalog.fetchq__%s__errors (';
	VAR_q = VAR_q || 'created_at, subject, message, details, ref_id';
    VAR_q = VAR_q || ') VALUES (';
    VAR_q = VAR_q || 'NOW(), ';
    VAR_q = VAR_q || '''%s'', ';
    VAR_q = VAR_q || '''%s'', ';
    VAR_q = VAR_q || '''%s'', ';
    VAR_q = VAR_q || '''%s'' ';
	VAR_q = VAR_q || ')';
    VAR_q = FORMAT(VAR_q, PAR_queue, PAR_subject, PAR_message, PAR_details, PAR_refId);

    EXECUTE VAR_q;
    GET DIAGNOSTICS queued_logs := ROW_COUNT;

    -- handle exception
	EXCEPTION WHEN OTHERS THEN BEGIN
		queued_logs = 0;
	END;
END; $$
LANGUAGE plpgsql;

-- UPSERTS A DOMAIN AND APPARENTLY HANDLES CONCURRENT ACCESS
-- returns:
-- { domain_id: '1' }
DROP FUNCTION IF EXISTS fetchq_queue_get_id(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_queue_get_id (
	PAR_queue VARCHAR(15),
	OUT queue_id BIGINT
) AS
$BODY$
BEGIN
	SELECT id INTO queue_id FROM fetchq_catalog.fetchq_sys_queues
	WHERE name = PAR_queue
	LIMIT 1;

	IF queue_id IS NULL THEN
		INSERT INTO fetchq_catalog.fetchq_sys_queues (name, created_at ) VALUES (PAR_queue, now())
		ON CONFLICT DO NOTHING
		RETURNING id INTO queue_id;
	END IF;
END;
$BODY$
LANGUAGE plpgsql;
-- Event Shapes:
-- fetchq__{queue_name}__{pnd|pln|act|cpl|kll}
--
-- Es: fetchq__foo__pnd
--


CREATE OR REPLACE FUNCTION fetchq_trigger_docs_notify_insert () RETURNS TRIGGER AS $$
DECLARE
	VAR_event VARCHAR = 'pnd';
    VAR_notify VARCHAR;
BEGIN
	IF NEW.next_iteration > NOW() THEN
		VAR_event = 'pln';
	END IF;

    VAR_notify = REPLACE(TG_TABLE_NAME, '__documents', FORMAT('__%s', VAR_event));
    -- RAISE EXCEPTION 'GGGG %', VAR_notify;
    -- RAISE EXCEPTION '>>>>>>>>>>>>>>>>> % -- %', VAR_notify, FORMAT('__%s', VAR_event);

    -- -- PERFORM pg_notify('fetchq_debug', VAR_notify);
	PERFORM pg_notify(VAR_notify, NEW.subject);
	RETURN NEW;
END; $$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fetchq_trigger_docs_notify_update () RETURNS TRIGGER AS $$
DECLARE
	VAR_event VARCHAR = 'null';
    VAR_notify VARCHAR;
BEGIN
	IF NEW.status = 0 THEN
		VAR_event = 'pln';
	END IF;

    IF NEW.status = 1 THEN
		VAR_event = 'pnd';
	END IF;

    IF NEW.status = 2 THEN
		VAR_event = 'act';
	END IF;

    IF NEW.status = 3 THEN
		VAR_event = 'cpl';
	END IF;

    IF NEW.status = -1 THEN
		VAR_event = 'kll';
	END IF;
	
    VAR_notify = REPLACE(TG_TABLE_NAME, '__documents', FORMAT('__%s', VAR_event));
    -- PERFORM pg_notify('fetchq_debug', VAR_notify);
	PERFORM pg_notify(VAR_notify, NEW.subject);
	RETURN NEW;
END; $$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION fetchq_queue_disable_notify (
    PAR_queue VARCHAR,
    OUT success BOOLEAN
) AS $$
DECLARE
	VAR_q VARCHAR;
BEGIN
	-- after insert
    VAR_q = 'DROP TRIGGER IF EXISTS fetchq__%s__trg_notify_insert ON fetchq_catalog.fetchq__%s__documents';
    VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue);
    EXECUTE VAR_q;

    -- after update
    VAR_q = 'DROP TRIGGER IF EXISTS fetchq__%s__trg_notify_update ON fetchq_catalog.fetchq__%s__documents';
    VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue);
    EXECUTE VAR_q;

    success = true;
END; $$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fetchq_queue_enable_notify (
    PAR_queue VARCHAR,
    OUT success BOOLEAN
) AS $$
DECLARE
	VAR_q VARCHAR;
BEGIN
	-- drop existing
    PERFORM fetchq_queue_disable_notify(PAR_queue);
    
    -- after insert
    VAR_q = 'CREATE TRIGGER fetchq__%s__trg_notify_insert AFTER INSERT ';
	VAR_q = VAR_q || 'ON fetchq_catalog.fetchq__%s__documents ';
    VAR_q = VAR_q || 'FOR EACH ROW EXECUTE PROCEDURE fetchq_trigger_docs_notify_insert();';
    VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue);
    EXECUTE VAR_q;


    -- after update
    VAR_q = 'CREATE TRIGGER fetchq__%s__trg_notify_update AFTER UPDATE ';
	VAR_q = VAR_q || 'ON fetchq_catalog.fetchq__%s__documents ';
    VAR_q = VAR_q || 'FOR EACH ROW EXECUTE PROCEDURE fetchq_trigger_docs_notify_update();';
    VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue);
    EXECUTE VAR_q;

    success = true;
END; $$
LANGUAGE plpgsql;

-- CREATED A QUEUE
-- returns:
-- { was_created: TRUE }
DROP FUNCTION IF EXISTS fetchq_queue_create(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_queue_create (
	PAR_queue VARCHAR,
	OUT was_created BOOLEAN,
	OUT queue_id INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
BEGIN
	was_created = TRUE;

	-- pick the queue id, it creates the queue's index entry if doesn't exists already
	SELECT t.queue_id INTO queue_id FROM fetchq_queue_get_id(PAR_queue) AS t;

	VAR_q = 'CREATE TABLE fetchq_catalog.fetchq__%s__documents (';
	VAR_q = VAR_q || 'subject CHARACTER VARYING(50) NOT NULL PRIMARY KEY,';
	VAR_q = VAR_q || 'version INTEGER DEFAULT 0,';
	VAR_q = VAR_q || 'priority INTEGER DEFAULT 0,';
	VAR_q = VAR_q || 'status INTEGER DEFAULT 0,';
	VAR_q = VAR_q || 'attempts INTEGER DEFAULT 0,';
	VAR_q = VAR_q || 'iterations INTEGER DEFAULT 0,';
	VAR_q = VAR_q || 'next_iteration TIMESTAMP WITH TIME ZONE,';
	VAR_q = VAR_q || 'lock_upgrade TIMESTAMP WITH TIME ZONE,';
	VAR_q = VAR_q || 'created_at TIMESTAMP WITH TIME ZONE,';
	VAR_q = VAR_q || 'last_iteration TIMESTAMP WITH TIME ZONE,';
	VAR_q = VAR_q || 'payload JSONB,';
	VAR_q = VAR_q || 'UNIQUE(subject)';
	VAR_q = VAR_q || ');';
	VAR_q = FORMAT(VAR_q, PAR_queue);
	EXECUTE VAR_q;

	-- errors table
	VAR_q = 'CREATE TABLE fetchq_catalog.fetchq__%s__errors (';
	VAR_q = VAR_q || 'id SERIAL PRIMARY KEY,';
	VAR_q = VAR_q || 'created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),';
	VAR_q = VAR_q || 'subject CHARACTER VARYING(50) NOT NULL,';
	VAR_q = VAR_q || 'message CHARACTER VARYING(255) NOT NULL,';
	VAR_q = VAR_q || 'details JSONB,';
	VAR_q = VAR_q || 'ref_id VARCHAR';
	VAR_q = VAR_q || ');';
	VAR_q = FORMAT(VAR_q, PAR_queue);
	EXECUTE VAR_q;

	-- stats history
	VAR_q = 'CREATE TABLE fetchq_catalog.fetchq__%s__metrics (';
	VAR_q = VAR_q || 'id SERIAL PRIMARY KEY,';
	VAR_q = VAR_q || 'created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),';
	VAR_q = VAR_q || 'metric CHARACTER VARYING(50) NOT NULL,';
	VAR_q = VAR_q || 'value bigint';
	VAR_q = VAR_q || ');';
	VAR_q = FORMAT(VAR_q, PAR_queue);
	EXECUTE VAR_q;

	-- add indexes to the table
	PERFORM fetchq_queue_create_indexes(PAR_queue);
	
	-- enable notifications
	-- (slows down by half insert performance!)
	-- PERFORM fetchq_queue_enable_notify(PAR_queue);

	-- add new maintenance tasks
	INSERT INTO fetchq_catalog.fetchq_sys_jobs (task, queue, next_iteration, last_iteration, attempts, iterations, settings, payload) VALUES
	('mnt', PAR_queue, NOW(), NULL, 0, 0, '{"delay":"1m", "duration":"5m", "limit":500}', '{}'),
	('sts', PAR_queue, NOW(), NULL, 0, 0, '{"delay":"3s", "duration":"5m"}', '{}'),
	('cmp', PAR_queue, NOW(), NULL, 0, 0, '{"delay":"10m", "duration":"5m"}', '{}'),
	('drp', PAR_queue, NOW(), NULL, 0, 0, '{"delay":"10m", "duration":"5m"}', '{}')
	ON CONFLICT DO NOTHING;

	-- send out notifications
	PERFORM pg_notify('fetchq_queue_create', PAR_queue);

	EXCEPTION WHEN OTHERS THEN BEGIN
		was_created = FALSE;
	END;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_queue_create_indexes(CHARACTER VARYING, INTEGER, INTEGER);
CREATE OR REPLACE FUNCTION fetchq_queue_create_indexes (
	PAR_queue VARCHAR,
    PAR_version INTEGER,
    PAR_attempts INTEGER,
	OUT was_created BOOLEAN
) AS $$
DECLARE
	-- VAR_table_name VARCHAR = 'fetchq__';
	VAR_q VARCHAR;
BEGIN
	was_created = TRUE;

    -- index for: fetchq_doc_pick()
    VAR_q = 'CREATE INDEX IF NOT EXISTS fetchq_%s_for_pick_%s_idx ON fetchq_catalog.fetchq__%s__documents ';
	VAR_q = VAR_q || '( priority DESC, next_iteration ASC, attempts ASC ) ';
    VAR_q = VAR_q || 'WHERE ( lock_upgrade IS NULL AND status = 1 AND version = %s); ';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_version, PAR_queue, PAR_version);
	EXECUTE VAR_q;

	-- index for: fetchq_mnt_make_pending()
	VAR_q = 'CREATE INDEX IF NOT EXISTS fetchq_%s_for_pnd_idx ON fetchq_catalog.fetchq__%s__documents ';
	VAR_q = VAR_q || '( next_iteration ASC, attempts ASC ) ';
	VAR_q = VAR_q || 'WHERE ( lock_upgrade IS NULL AND status = 0 ); ';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue);
	EXECUTE VAR_q;

	-- index for: fetchq_mnt_reschedule_orphans()
	VAR_q = 'CREATE INDEX IF NOT EXISTS fetchq_%s_for_orp_idx ON fetchq_catalog.fetchq__%s__documents ';
	VAR_q = VAR_q || '( next_iteration ASC, attempts ASC ) ';
	VAR_q = VAR_q || 'WHERE ( lock_upgrade IS NULL AND status = 2 AND attempts < %s ); ';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue, PAR_attempts);
	EXECUTE VAR_q;

	-- index for: fetchq_mnt_mark_dead()
	VAR_q = 'CREATE INDEX IF NOT EXISTS fetchq_%s_for_dod_idx ON fetchq_catalog.fetchq__%s__documents ';
	VAR_q = VAR_q || '( next_iteration ASC, attempts ASC ) ';
	VAR_q = VAR_q || 'WHERE ( lock_upgrade IS NULL AND status = 2 AND attempts >= %s ); ';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue, PAR_attempts);
	EXECUTE VAR_q;

	-- index for: fetchq_doc_upsert() -- edit query
	VAR_q = 'CREATE INDEX IF NOT EXISTS fetchq_%s_for_ups_idx ON fetchq_catalog.fetchq__%s__documents ';
	VAR_q = VAR_q || '( subject ) ';
	VAR_q = VAR_q || 'WHERE ( lock_upgrade IS NULL AND status <> 2 ); ';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue, PAR_attempts);
	EXECUTE VAR_q;

	EXCEPTION WHEN OTHERS THEN BEGIN
		was_created = FALSE;
	END;
END; $$
LANGUAGE plpgsql;


-- Reads the index settings from the queue index table and invokes the
-- specialized method with the current queue settings
DROP FUNCTION IF EXISTS fetchq_queue_create_indexes(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_queue_create_indexes (
	PAR_queue VARCHAR,
	OUT was_created BOOLEAN
) AS $$
DECLARE
	VAR_q VARCHAR;
	VAR_R RECORD;
BEGIN
	was_created = TRUE;

	SELECT * INTO VAR_r FROM fetchq_catalog.fetchq_sys_queues WHERE name = PAR_queue;
	PERFORM fetchq_queue_create_indexes(PAR_queue, VAR_r.current_version, VAR_r.max_attempts);

	EXCEPTION WHEN OTHERS THEN BEGIN
		was_created = FALSE;
	END;
END; $$
LANGUAGE plpgsql;


-- DROP A QUEUE
-- returns:
-- { was_dropped: TRUE }
DROP FUNCTION IF EXISTS fetchq_queue_drop(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_queue_drop (
	PAR_queue VARCHAR,
	OUT was_dropped BOOLEAN,
	OUT queue_id INTEGER
) AS $$
DECLARE
	VAR_tableName VARCHAR = 'fetchq_catalog.fetchq__';
	VAR_q VARCHAR;
	VAR_r RECORD;
BEGIN
	was_dropped = TRUE;
	VAR_tableName = VAR_tableName || PAR_queue;

	-- drop indexes
	-- PERFORM fetchq_queue_drop_indexes(PAR_queue);

	-- drop queue table
	VAR_q = 'DROP TABLE %s__documents CASCADE;';
	VAR_q = FORMAT(VAR_q, VAR_tableName);
	EXECUTE VAR_q;

	-- drop errors table
	VAR_q = 'DROP TABLE %s__errors CASCADE;';
	VAR_q = FORMAT(VAR_q, VAR_tableName);
	EXECUTE VAR_q;

	-- drop stats table
	VAR_q = 'DROP TABLE %s__metrics CASCADE;';
	VAR_q = FORMAT(VAR_q, VAR_tableName);
	EXECUTE VAR_q;

	-- drop domain namespace
	DELETE FROM fetchq_catalog.fetchq_sys_queues
	WHERE name = PAR_queue RETURNING id INTO VAR_r;
	queue_id = VAR_r.id;

	-- drop maintenance tasks
	DELETE FROM fetchq_catalog.fetchq_sys_jobs WHERE queue = PAR_queue;

	-- drop counters
	DELETE FROM fetchq_catalog.fetchq_sys_metrics
	WHERE queue = PAR_queue;

	-- drop metrics logs
	DELETE FROM fetchq_catalog.fetchq_sys_metrics_writes
	WHERE queue = PAR_queue;

	-- send out notifications
	PERFORM pg_notify('fetchq_queue_drop', PAR_queue);

	EXCEPTION WHEN OTHERS THEN BEGIN
		was_dropped = FALSE;
	END;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_queue_set_max_attempts(CHARACTER VARYING, INTEGER);
CREATE OR REPLACE FUNCTION fetchq_queue_set_max_attempts (
	PAR_queue VARCHAR,
	PAR_maxAttempts INTEGER,
	OUT affected_rows INTEGER,
	OUT was_reindexed BOOLEAN
) AS $$
DECLARE
	VAR_q VARCHAR;
	VAR_r RECORD;
BEGIN
	-- initial values
	affected_rows = 0;
	was_reindexed = true;

	-- change max_attempts in the table
	VAR_q = '';
	VAR_q = VAR_q || 'UPDATE fetchq_catalog.fetchq_sys_queues ';
	VAR_q = VAR_q || 'SET max_attempts = %s  ';
	VAR_q = VAR_q || 'WHERE name = ''%s'' RETURNING current_version';
	VAR_q = FORMAT(VAR_q, PAR_maxAttempts, PAR_queue);
	EXECUTE VAR_q INTO VAR_r;
	GET DIAGNOSTICS affected_rows := ROW_COUNT;

	-- drop max_attempts related indexes
	VAR_q = 'DROP INDEX IF EXISTS fetchq_catalog.fetchq_%s_for_orp_idx';
	EXECUTE FORMAT(VAR_q, PAR_queue);
	VAR_q = 'DROP INDEX IF EXISTS fetchq_catalog.fetchq_%s_for_dod_idx';
	EXECUTE FORMAT(VAR_q, PAR_queue);

	-- re-index the table
	-- RAISE NOTICE '%', VAR_r.current_version;
	PERFORM fetchq_queue_create_indexes(PAR_queue);

	EXCEPTION WHEN OTHERS THEN BEGIN
		was_reindexed = false;
	END;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_queue_set_current_version(CHARACTER VARYING, INTEGER);
CREATE OR REPLACE FUNCTION fetchq_queue_set_current_version (
	PAR_queue VARCHAR,
	PAR_newVersion INTEGER,
	OUT affected_rows INTEGER,
	OUT was_reindexed BOOLEAN
) AS $$
DECLARE
	VAR_q VARCHAR;
	VAR_r RECORD;
BEGIN
	-- initial values
	affected_rows = 0;
	was_reindexed = true;

	-- change max_attempts in the table
	VAR_q = '';
	VAR_q = VAR_q || 'UPDATE fetchq_catalog.fetchq_sys_queues ';
	VAR_q = VAR_q || 'SET current_version = %s  ';
	VAR_q = VAR_q || 'WHERE name = ''%s'' RETURNING max_attempts';
	VAR_q = FORMAT(VAR_q, PAR_newVersion, PAR_queue);
	EXECUTE VAR_q INTO VAR_r;
	GET DIAGNOSTICS affected_rows := ROW_COUNT;

	-- drop max_attempts related indexes
	VAR_q = 'DROP INDEX IF EXISTS fetchq_catalog.fetchq_%s_for_pick_idx';
	EXECUTE FORMAT(VAR_q, PAR_queue);
	VAR_q = 'DROP INDEX IF EXISTS fetchq_catalog.etchq_%s_for_pnd_idx';
	EXECUTE FORMAT(VAR_q, PAR_queue);

	-- re-index the table
	PERFORM fetchq_queue_create_indexes(PAR_queue);

	EXCEPTION WHEN OTHERS THEN BEGIN
		was_reindexed = false;
	END;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_queue_set_errors_retention(CHARACTER VARYING, CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_queue_set_errors_retention (
	PAR_queue VARCHAR,
	PAR_retention VARCHAR,
	OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
BEGIN
	-- initial values
	affected_rows = 0;

	-- change value in the table
	VAR_q = '';
	VAR_q = VAR_q || 'UPDATE fetchq_catalog.fetchq_sys_queues ';
	VAR_q = VAR_q || 'SET errors_retention = ''%s''  ';
	VAR_q = VAR_q || 'WHERE name = ''%s''';
	VAR_q = FORMAT(VAR_q, PAR_retention, PAR_queue);
	EXECUTE VAR_q;
	GET DIAGNOSTICS affected_rows := ROW_COUNT;

	EXCEPTION WHEN OTHERS THEN BEGIN
		affected_rows = 0;
	END;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_queue_set_metrics_retention(CHARACTER VARYING, CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_queue_set_metrics_retention (
	PAR_queue VARCHAR,
	PAR_retention VARCHAR,
	OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
BEGIN
	-- initial values
	affected_rows = 0;

	-- change value in the table
	VAR_q = '';
	VAR_q = VAR_q || 'UPDATE fetchq_sys_queues ';
	VAR_q = VAR_q || 'SET metrics_retention = ''%s''  ';
	VAR_q = VAR_q || 'WHERE name = ''%s''';
	VAR_q = FORMAT(VAR_q, PAR_retention, PAR_queue);
	EXECUTE VAR_q;
	GET DIAGNOSTICS affected_rows := ROW_COUNT;

	EXCEPTION WHEN OTHERS THEN BEGIN
		affected_rows = 0;
	END;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_queue_drop_version(CHARACTER VARYING, INTEGER);
CREATE OR REPLACE FUNCTION fetchq_queue_drop_version (
	PAR_queue VARCHAR,
	PAR_oldVersion INTEGER,
	OUT was_dropped BOOLEAN
) AS $$
DECLARE
	VAR_q VARCHAR;
	VAR_r RECORD;
BEGIN
	-- initial values
	was_dropped = true;

	-- @TODO: check that this is not the current index
	VAR_q = '';
	VAR_q = VAR_q || 'SELECT id FROM fetchq_catalog.fetchq_sys_queues ';
	VAR_q = VAR_q || 'WHERE name = ''%s'' AND current_version = %s';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_oldVersion);
	EXECUTE VAR_q INTO VAR_r;

    IF VAR_r.id IS NOT NULL THEN
        RAISE EXCEPTION 'can not drop current version: %', PAR_oldVersion;
    END IF;

	-- drop old index
	VAR_q = 'DROP INDEX IF EXISTS fetchq_catalog.fetchq_%s_for_pick_%s_idx';
	EXECUTE FORMAT(VAR_q, PAR_queue, PAR_oldVersion);

	EXCEPTION WHEN OTHERS THEN BEGIN
		was_dropped = false;
	END;
END; $$
LANGUAGE plpgsql;

-- DROP A QUEUE ERRORS WITH A RETENTION INTERVAL
-- returns:
-- { affected_rows: INTEGER }
DROP FUNCTION IF EXISTS fetchq_queue_drop_errors(CHARACTER VARYING, CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_queue_drop_errors (
	PAR_queue VARCHAR,
    PAR_retention VARCHAR,
	OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
	VAR_r RECORD;
BEGIN
	VAR_q = 'DELETE FROM fetchq_catalog.fetchq__%s__errors WHERE created_at < NOW() - INTERVAL ''%s'';';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_retention);
	EXECUTE VAR_q;
    GET DIAGNOSTICS affected_rows := ROW_COUNT;

	EXCEPTION WHEN OTHERS THEN BEGIN
		affected_rows = 0;
	END;
END; $$
LANGUAGE plpgsql;


-- DROP A QUEUE ERRORS WITH A RETENTION DATE
-- returns:
-- { affected_rows: INTEGER }
DROP FUNCTION IF EXISTS fetchq_queue_drop_errors(CHARACTER VARYING, TIMESTAMP WITH TIME ZONE);
CREATE OR REPLACE FUNCTION fetchq_queue_drop_errors (
	PAR_queue VARCHAR,
    PAR_retention TIMESTAMP WITH TIME ZONE,
	OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
	VAR_r RECORD;
BEGIN
	VAR_q = 'DELETE FROM fetchq_catalog.fetchq__%s__errors WHERE created_at < ''%s'';';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_retention);
	EXECUTE VAR_q;
    GET DIAGNOSTICS affected_rows := ROW_COUNT;

	EXCEPTION WHEN OTHERS THEN BEGIN
		affected_rows = 0;
	END;
END; $$
LANGUAGE plpgsql;


-- DROP A QUEUE ERRORS WITH A RETENTION FROM QUEUE SETTINGS
-- returns:
-- { affected_rows: INTEGER }
DROP FUNCTION IF EXISTS fetchq_queue_drop_errors(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_queue_drop_errors (
	PAR_queue VARCHAR,
	OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
	VAR_r RECORD;
    VAR_retention VARCHAR = '24h';
BEGIN
    VAR_q = 'SELECT errors_retention FROM fetchq_catalog.fetchq_sys_queues WHERE name = ''%s'';';
	VAR_q = FORMAT(VAR_q, PAR_queue);
	EXECUTE VAR_q INTO VAR_r;

    -- override the default value
    IF VAR_r.errors_retention IS NOT NULL THEN
        VAR_retention = VAR_r.errors_retention;
    END IF;

    SELECT * INTO VAR_r FROM fetchq_queue_drop_errors(PAR_queue, VAR_retention);
    affected_rows = VAR_r.affected_rows;

	EXCEPTION WHEN OTHERS THEN BEGIN
		affected_rows = 0;
	END;
END; $$
LANGUAGE plpgsql;

-- DROP A QUEUE ERRORS WITH A RETENTION INTERVAL
-- returns:
-- { affected_rows: INTEGER }
DROP FUNCTION IF EXISTS fetchq_queue_drop_metrics(CHARACTER VARYING, JSONB);
CREATE OR REPLACE FUNCTION fetchq_queue_drop_metrics (
	PAR_queue VARCHAR,
    PAR_config JSONB,
	OUT removed_rows INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
	VAR_r RECORD;
    VAR_rowSrc TEXT;
    VAR_rowCfg RECORD;
    VAR_rowRes RECORD;
BEGIN
    removed_rows = 0;
    -- RAISE NOTICE '%', PAR_config;

    FOR VAR_r IN SELECT value::jsonb FROM jsonb_array_elements(PAR_config)
    LOOP
        VAR_rowSrc = VAR_r.value;
        VAR_rowSrc = REPLACE(VAR_rowSrc, 'from', 'a' );
        VAR_rowSrc = REPLACE(VAR_rowSrc, 'to', 'b' );
        VAR_rowSrc = REPLACE(VAR_rowSrc, 'retain', 'c' );
        select * INTO VAR_rowCfg from jsonb_to_record(VAR_rowSrc::jsonb) as x(a text, b text, c text);
        -- RAISE NOTICE 'from: %, to: %, retain: %', VAR_rowCfg.a, VAR_rowCfg.b, VAR_rowCfg.c;

        VAR_q = 'SELECT * FROM fetchq_utils_ts_retain(''fetchq__%s__metrics'', ''created_at'', ''%s'', NOW() - INTERVAL ''%s'', NOW() - INTERVAL ''%s'')';
        VAR_q = FORMAT(VAR_q, PAR_queue, VAR_rowCfg.c, VAR_rowCfg.a, VAR_rowCfg.b);
        -- RAISE NOTICE '%', VAR_q;
        EXECUTE VAR_q INTO VAR_rowRes;

        removed_rows = removed_rows + VAR_rowRes.removed_rows;
    END LOOP;

    -- RAISE NOTICE 'removed roes %', removed_rows;
	EXCEPTION WHEN OTHERS THEN BEGIN
		removed_rows = 0;
	END;
END; $$
LANGUAGE plpgsql;


DROP FUNCTION IF EXISTS fetchq_queue_drop_metrics(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_queue_drop_metrics (
	PAR_queue VARCHAR,
	OUT removed_rows INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
	VAR_r RECORD;
    VAR_retention VARCHAR = '[]';
BEGIN
    
    VAR_q = 'SELECT metrics_retention FROM fetchq_catalog.fetchq_sys_queues WHERE name = ''%s'';';
	VAR_q = FORMAT(VAR_q, PAR_queue);
	EXECUTE VAR_q INTO VAR_r;

    -- override the default value
    IF VAR_r.metrics_retention IS NOT NULL THEN
        VAR_retention = VAR_r.metrics_retention;
    END IF;

    RAISE NOTICE 'retention %', VAR_retention;

    -- run the operation
    SELECT * INTO VAR_r FROM fetchq_queue_drop_metrics(PAR_queue, VAR_retention::jsonb);
    removed_rows = VAR_r.removed_rows;

    -- RAISE NOTICE 'removed roes %', removed_rows;
	EXCEPTION WHEN OTHERS THEN BEGIN
		removed_rows = 0;
	END;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_queue_drop_indexes(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_queue_drop_indexes (
	PAR_queue VARCHAR,
	OUT was_dropped BOOLEAN
) AS $$
DECLARE
	-- VAR_table_name VARCHAR = 'fetchq__';
	VAR_q VARCHAR;
    VAR_r RECORD;
BEGIN
	was_dropped = TRUE;

    -- (select 'foo' as name)
    SELECT current_version INTO VAR_r FROM fetchq_catalog.fetchq_sys_queues WHERE name = PAR_queue;
    -- -- index for: fetchq_doc_pick()
    -- VAR_q = 'SELECT current_version INTO VAR_r FROM fetchq_catalog.fetchq_sys_queues WHERE name = ''%s'';';
    -- VAR_q = FORMAT(VAR_q, PAR_queue);
    -- EXECUTE VAR_q;

    VAR_q = 'DROP INDEX IF EXISTS fetchq_catalog.fetchq_%s_for_pick_%s_idx;';
	VAR_q = FORMAT(VAR_q, PAR_queue, VAR_r.current_version);
	EXECUTE VAR_q;

	-- index for: fetchq_mnt_make_pending()
	VAR_q = 'DROP INDEX IF EXISTS fetchq_catalog.fetchq_%s_for_pnd_idx;';
	VAR_q = FORMAT(VAR_q, PAR_queue);
	EXECUTE VAR_q;

	-- index for: fetchq_mnt_reschedule_orphans()
	VAR_q = 'DROP INDEX IF EXISTS fetchq_catalog.fetchq_%s_for_orp_idx;';
	VAR_q = FORMAT(VAR_q, PAR_queue);
	EXECUTE VAR_q;

	-- index for: fetchq_mnt_mark_dead()
	VAR_q = 'DROP INDEX IF EXISTS fetchq_catalog.fetchq_%s_for_dod_idx;';
	VAR_q = FORMAT(VAR_q, PAR_queue);
	EXECUTE VAR_q;

	-- index for: fetchq_doc_upsert() -- edit query
	VAR_q = 'DROP INDEX IF EXISTS fetchq_catalog.fetchq_%s_for_ups_idx;';
	VAR_q = FORMAT(VAR_q, PAR_queue);
	EXECUTE VAR_q;

	EXCEPTION WHEN OTHERS THEN BEGIN
		was_dropped = FALSE;
	END;
END; $$
LANGUAGE plpgsql;


DROP FUNCTION IF EXISTS fetchq_queue_top(CHARACTER VARYING, INTEGER, INTEGER, INTEGER);
CREATE OR REPLACE FUNCTION fetchq_queue_top (
	PAR_queue VARCHAR,
    PAR_version INTEGER,
    PAR_limit INTEGER,
    PAR_offset INTEGER
) RETURNS TABLE (
	subject VARCHAR,
	payload JSONB,
	version INTEGER,
	priority INTEGER,
	attempts INTEGER,
	iterations INTEGER,
	created_at TIMESTAMP WITH TIME ZONE,
	last_iteration TIMESTAMP WITH TIME ZONE,
	next_iteration TIMESTAMP WITH TIME ZONE,
	lock_upgrade TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
	VAR_tableName VARCHAR = 'fetchq_catalog.fetchq__';
	VAR_q VARCHAR;
	VAR_r RECORD;
BEGIN

    -- return documents
	VAR_q = 'SELECT subject, payload, version, priority, attempts, iterations, created_at, last_iteration, next_iteration, lock_upgrade ';
	VAR_q = VAR_q || 'FROM fetchq_catalog.fetchq__%s__documents ';
	VAR_q = VAR_q || 'WHERE version = %s ';
	VAR_q = VAR_q || 'LIMIT %s OFFSET %s';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_version, PAR_limit, PAR_offset);
	RETURN QUERY EXECUTE VAR_q;

END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_queue_status();
CREATE OR REPLACE FUNCTION fetchq_queue_status () RETURNS TABLE (
    id INTEGER,
	name VARCHAR,
	is_active BOOLEAN
) AS $$
DECLARE
    VAR_q VARCHAR;
BEGIN
    -- return documents
	-- VAR_q = 'SELECT id, name, is_active ';
	-- VAR_q = VAR_q || 'FROM fetchq_catalog.fetchq_sys_queues';
	-- -- VAR_q = FORMAT(VAR_q, PAR_queue, PAR_version, PAR_limit, PAR_offset);
	-- RETURN QUERY EXECUTE VAR_q;
    RETURN QUERY EXECUTE 'SELECT id, name, is_active FROM fetchq_catalog.fetchq_sys_queues';
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_queue_status(VARCHAR);
CREATE OR REPLACE FUNCTION fetchq_queue_status (
    PAR_queue VARCHAR
) RETURNS TABLE (
    id INTEGER,
	name VARCHAR,
	is_active BOOLEAN
) AS $$
DECLARE
    VAR_q VARCHAR;
BEGIN
    -- return documents
	VAR_q = 'SELECT id, name, is_active ';
	VAR_q = VAR_q || 'FROM fetchq_catalog.fetchq_sys_queues ';
	VAR_q = VAR_q || 'WHERE name = ''%s'' ';
	VAR_q = VAR_q || 'LIMIT 1';
	VAR_q = FORMAT(VAR_q, PAR_queue);
	RETURN QUERY EXECUTE VAR_q;
END; $$
LANGUAGE plpgsql;

-- DROP RECORDS FROM A GENERIC TIMESERIE TABLE
-- select (*) from lock_queue_drop_time( 'targetTable', 'timeField', 'retainAmount', 'older date', 'newer date')
-- retainAmount: microseconds | milliseconds | second | minute | hour | day | week | month | quarter | year | decade | century | millennium
DROP FUNCTION IF EXISTS fetchq_utils_ts_retain(character varying, character varying, character varying, timestamp with time zone, timestamp with time zone);
CREATE OR REPLACE FUNCTION fetchq_utils_ts_retain (
	tableName VARCHAR,
	fieldName VARCHAR,
	retainStr VARCHAR,
	intervalStart TIMESTAMP WITH TIME ZONE,
	intervalEnd TIMESTAMP WITH TIME ZONE,
	OUT removed_rows BIGINT
) AS $$
DECLARE
	q VARCHAR;
BEGIN

	q = 'DELETE FROM %s ';
	q = q || 'WHERE %s BETWEEN (''%s'') AND (''%s'') ';
	q = q || 'AND id NOT IN ( ';
	q = q || 'SELECT id FROM ( ';
	q = q || 'SELECT DISTINCT ON (lq_retention_fld) id, date_trunc(''%s'', %s) lq_retention_fld FROM %s ';
	q = q || 'WHERE %s BETWEEN (''%s'') AND (''%s'') ';
	q = q || 'ORDER BY lq_retention_fld, %s DESC ';
	q = q || ') AS lock_queue_drop_time_get_retained_ids';
	q = q || ') RETURNING id;';
	q = FORMAT(q, tableName, fieldName, intervalStart, intervalEnd, retainStr, fieldName, tableName, fieldName, intervalStart, intervalEnd, fieldName);

--	raise log '%', q;

	EXECUTE q;
	GET DIAGNOSTICS removed_rows := ROW_COUNT;
END; $$
LANGUAGE plpgsql;