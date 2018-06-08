
-- Queues Index
CREATE TABLE fetchq_sys_queues (
    id BIGINT NOT NULL,
    name CHARACTER VARYING(50) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE,
    config JSON DEFAULT '{}'
);

CREATE SEQUENCE fetchq_sys_queues_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE fetchq_sys_queues_id_seq OWNED BY fetchq_sys_queues.id;
ALTER TABLE ONLY fetchq_sys_queues ALTER COLUMN id SET DEFAULT nextval('fetchq_sys_queues_id_seq'::regclass);
ALTER TABLE ONLY fetchq_sys_queues ADD CONSTRAINT fetchq_sys_queues_name_key UNIQUE (name);
ALTER TABLE ONLY fetchq_sys_queues ADD CONSTRAINT fetchq_sys_queues_pkey PRIMARY KEY (id);

-- Metrics Overview
CREATE TABLE fetchq_sys_metrics (
    id BIGINT NOT NULL,
    queue CHARACTER VARYING(25) NOT NULL,
    metric CHARACTER VARYING(25) NOT NULL,
    value BIGINT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE SEQUENCE fetchq_sys_metrics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 100;

ALTER SEQUENCE fetchq_sys_metrics_id_seq OWNED BY fetchq_sys_metrics.id;
ALTER TABLE ONLY fetchq_sys_metrics ALTER COLUMN id SET DEFAULT nextval('fetchq_sys_metrics_id_seq'::regclass);
ALTER TABLE ONLY fetchq_sys_metrics ADD CONSTRAINT fetchq_sys_metrics_pkey PRIMARY KEY (id, queue, metric);
CREATE INDEX fetchq_sys_metrics_queue_idx ON fetchq_sys_metrics USING btree (queue);

-- Metrics Writes
CREATE TABLE fetchq_sys_metrics_writes (
    id BIGINT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE,
    queue CHARACTER VARYING(25) NOT NULL,
    metric CHARACTER VARYING(25) NOT NULL,
    increment BIGINT,
    reset BIGINT
);

CREATE SEQUENCE fetchq_sys_metrics_writes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 10000;

ALTER SEQUENCE fetchq_sys_metrics_writes_id_seq OWNED BY fetchq_sys_metrics_writes.id;
ALTER TABLE ONLY fetchq_sys_metrics_writes ALTER COLUMN id SET DEFAULT nextval('fetchq_sys_metrics_writes_id_seq'::regclass);
ALTER TABLE ONLY fetchq_sys_metrics_writes ADD CONSTRAINT fetchq_sys_metrics_writes_pkey PRIMARY KEY (id);
CREATE INDEX fetchq_sys_metrics_writes_reset_idx ON fetchq_sys_metrics_writes ( queue, metric ) WHERE ( reset IS NOT NULL );
CREATE INDEX fetchq_sys_metrics_writes_increment_idx ON fetchq_sys_metrics_writes ( queue, metric ) WHERE ( increment IS NOT NULL );

-- Maintenance Jobs
CREATE TABLE fetchq_sys_jobs (
    id bigint NOT NULL,
    domain character varying(50) NOT NULL,
    subject character varying(50) NOT NULL,
    attempts integer DEFAULT 0,
    iterations integer DEFAULT 0,
    next_iteration timestamp with time zone,
    last_iteration timestamp with time zone,
    settings jsonb,
    payload jsonb
);

CREATE SEQUENCE fetchq_sys_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE fetchq_sys_jobs_id_seq OWNED BY fetchq_sys_jobs.id;
ALTER TABLE ONLY fetchq_sys_jobs ALTER COLUMN id SET DEFAULT nextval('fetchq_sys_jobs_id_seq'::regclass);
ALTER TABLE ONLY fetchq_sys_jobs ADD CONSTRAINT fetchq_sys_jobs_pkey PRIMARY KEY (id);
CREATE UNIQUE INDEX fetchq_sys_jobs_domain_subject_idx ON fetchq_sys_jobs USING btree (domain, subject);
CREATE INDEX fetchq_sys_jobs_domain_idx ON fetchq_sys_jobs USING btree (domain, next_iteration, iterations) WHERE (iterations < 5);
-- UPSERTS A DOMAIN AND APPARENTLY HANDLES CONCURRENT ACCESS
-- returns:
-- { domain_id: '1' }
DROP FUNCTION IF EXISTS fetchq_get_queue_id(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_get_queue_id (
	PAR_domainStr VARCHAR(15),
	OUT queue_id BIGINT
) AS
$BODY$
BEGIN
	SELECT id INTO queue_id FROM fetchq_sys_queues
	WHERE name = PAR_domainStr
	LIMIT 1;

	IF queue_id IS NULL THEN
		INSERT INTO fetchq_sys_queues (name, created_at ) VALUES (PAR_domainStr, now())
		ON CONFLICT DO NOTHING
		RETURNING id INTO queue_id;
	END IF;
END;
$BODY$
LANGUAGE plpgsql;

-- CREATED A QUEUE
-- returns:
-- { was_created: TRUE }
DROP FUNCTION IF EXISTS fetchq_create_queue(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_create_queue (
	PAR_domainStr VARCHAR,
	OUT was_created BOOLEAN,
	OUT queue_id BIGINT
) AS $$
DECLARE
	-- VAR_table_name VARCHAR = 'fetchq__';
	VAR_q VARCHAR;
BEGIN
	was_created = TRUE;
	-- VAR_table_name = VAR_table_name || PAR_domainStr;

	-- pick the queue id
	SELECT t.queue_id INTO queue_id FROM fetchq_get_queue_id(PAR_domainStr) AS t;

	VAR_q = 'CREATE TABLE fetchq__%s__documents (';
	VAR_q = VAR_q || 'id SERIAL PRIMARY KEY,';
	VAR_q = VAR_q || 'subject CHARACTER VARYING(50) NOT NULL,';
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
	VAR_q = FORMAT(VAR_q, PAR_domainStr);
	EXECUTE VAR_q;

	-- errors table
	VAR_q = 'CREATE TABLE fetchq__%s__errors (';
	VAR_q = VAR_q || 'id SERIAL PRIMARY KEY,';
	VAR_q = VAR_q || 'process_id BIGINT,';
	VAR_q = VAR_q || 'subject CHARACTER VARYING(50) NOT NULL,';
	VAR_q = VAR_q || 'created_at TIMESTAMP WITH TIME ZONE,';
	VAR_q = VAR_q || 'message CHARACTER VARYING(255) NOT NULL,';
	VAR_q = VAR_q || 'details JSONB';
	VAR_q = VAR_q || ');';
	VAR_q = FORMAT(VAR_q, PAR_domainStr);
	EXECUTE VAR_q;

	-- stats history
	VAR_q = 'CREATE TABLE fetchq__%s__metrics (';
	VAR_q = VAR_q || 'id SERIAL PRIMARY KEY,';
	VAR_q = VAR_q || 'metric CHARACTER VARYING(50) NOT NULL,';
	VAR_q = VAR_q || 'value bigint,';
	VAR_q = VAR_q || 'ts TIMESTAMP WITH TIME ZONE';
	VAR_q = VAR_q || ');';
	VAR_q = FORMAT(VAR_q, PAR_domainStr);
	EXECUTE VAR_q;

	-- add indexes
	--PERFORM lq_create_indexes(PAR_domainStr, 0);

	-- add new maintenance tasks
	INSERT INTO fetchq_sys_jobs (domain, subject, next_iteration, last_iteration, attempts, iterations, settings, payload) VALUES
	('mnt', PAR_domainStr, NOW(), NULL, 0, 0, '{}', '{}'),
	('sts', PAR_domainStr, NOW(), NULL, 0, 0, '{}', '{}'),
	('cmp', PAR_domainStr, NOW(), NULL, 0, 0, '{}', '{}'),
	('cln', PAR_domainStr, NOW(), NULL, 0, 0, '{}', '{}')
	ON CONFLICT DO NOTHING;

	EXCEPTION WHEN OTHERS THEN BEGIN
		was_created = FALSE;
	END;
END; $$
LANGUAGE plpgsql;

-- DROP A QUEUE
-- returns:
-- { was_dropped: TRUE }
DROP FUNCTION IF EXISTS fetchq_drop_queue(character varying);
CREATE OR REPLACE FUNCTION fetchq_drop_queue (
	domainStr VARCHAR,
	OUT was_dropped BOOLEAN
) AS $$
DECLARE
	table_name VARCHAR = 'fetchq__';
	drop_query VARCHAR;
BEGIN
	was_dropped = TRUE;
	table_name = table_name || domainStr;

	-- drop indexes
	-- PERFORM fetchq_drop_queue_indexes(domainStr);

	-- drop queue table
	drop_query = 'DROP TABLE %s__documents;';
	drop_query = FORMAT(drop_query, table_name);
	EXECUTE drop_query;

	-- drop errors table
	drop_query = 'DROP TABLE %s__errors;';
	drop_query = FORMAT(drop_query, table_name);
	EXECUTE drop_query;

	-- drop stats table
	drop_query = 'DROP TABLE %s__metrics;';
	drop_query = FORMAT(drop_query, table_name);
	EXECUTE drop_query;

	-- drop domain namespace
	DELETE FROM fetchq_sys_queues
	WHERE name = domainStr;

	-- drop maintenance tasks
	DELETE FROM fetchq_sys_jobs WHERE subject = domainStr;

	-- drop counters
	-- DELETE FROM lq__metrics
	-- WHERE queue = domainStr;

	-- drop metrics logs
	-- DELETE FROM lq__metrics_writes
	-- WHERE queue = domainStr;

	EXCEPTION WHEN OTHERS THEN BEGIN
		was_dropped = FALSE;
	END;
END; $$
LANGUAGE plpgsql;
