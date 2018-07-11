
DROP FUNCTION IF EXISTS fetchq_init();
CREATE OR REPLACE FUNCTION fetchq_init (
    OUT was_initialized BOOLEAN
) AS $$
BEGIN

    -- Queues Index
    CREATE TABLE IF NOT EXISTS fetchq_sys_queues (
        id SERIAL PRIMARY KEY,
        created_at TIMESTAMP WITH TIME ZONE,
        name CHARACTER VARYING(40) NOT NULL,
        is_active BOOLEAN DEFAULT true,
        current_version INTEGER DEFAULT 0,
        max_attempts INTEGER DEFAULT 5,
        errors_retention VARCHAR(25) DEFAULT '24h',
        metrics_retention JSONB DEFAULT '[]',
        config JSON DEFAULT '{}'
    );

    -- CREATE SEQUENCE fetchq_sys_queues_id_seq
    --     START WITH 1
    --     INCREMENT BY 1
    --     NO MINVALUE
    --     NO MAXVALUE
    --     CACHE 1;

    -- ALTER SEQUENCE fetchq_sys_queues_id_seq OWNED BY fetchq_sys_queues.id;
    -- ALTER TABLE ONLY fetchq_sys_queues ALTER COLUMN id SET DEFAULT nextval('fetchq_sys_queues_id_seq'::regclass);
    -- ALTER TABLE ONLY fetchq_sys_queues ADD CONSTRAINT fetchq_sys_queues_name_key UNIQUE (name);
    -- ALTER TABLE ONLY fetchq_sys_queues ADD CONSTRAINT fetchq_sys_queues_pkey PRIMARY KEY (id);

    -- Metrics Overview
    CREATE TABLE IF NOT EXISTS fetchq_sys_metrics (
        id SERIAL PRIMARY KEY,
        queue CHARACTER VARYING(40) NOT NULL,
        metric CHARACTER VARYING(40) NOT NULL,
        value BIGINT NOT NULL,
        updated_at TIMESTAMP WITH TIME ZONE
    );

    -- CREATE SEQUENCE fetchq_sys_metrics_id_seq
    --     START WITH 1
    --     INCREMENT BY 1
    --     NO MINVALUE
    --     NO MAXVALUE
    --     CACHE 100;

    -- ALTER SEQUENCE fetchq_sys_metrics_id_seq OWNED BY fetchq_sys_metrics.id;
    -- ALTER TABLE ONLY fetchq_sys_metrics ALTER COLUMN id SET DEFAULT nextval('fetchq_sys_metrics_id_seq'::regclass);
    -- ALTER TABLE ONLY fetchq_sys_metrics ADD CONSTRAINT fetchq_sys_metrics_pkey PRIMARY KEY (id, queue, metric);
    CREATE INDEX IF NOT EXISTS fetchq_sys_metrics_queue_idx ON fetchq_sys_metrics USING btree (queue);

    -- Metrics Writes
    CREATE TABLE IF NOT EXISTS fetchq_sys_metrics_writes (
        id SERIAL PRIMARY KEY,
        created_at TIMESTAMP WITH TIME ZONE,
        queue CHARACTER VARYING(40) NOT NULL,
        metric CHARACTER VARYING(40) NOT NULL,
        increment BIGINT,
        reset BIGINT
    );

    -- CREATE SEQUENCE fetchq_sys_metrics_writes_id_seq
    --     START WITH 1
    --     INCREMENT BY 1
    --     NO MINVALUE
    --     NO MAXVALUE
    --     CACHE 10000;

    -- ALTER SEQUENCE fetchq_sys_metrics_writes_id_seq OWNED BY fetchq_sys_metrics_writes.id;
    -- ALTER TABLE ONLY fetchq_sys_metrics_writes ALTER COLUMN id SET DEFAULT nextval('fetchq_sys_metrics_writes_id_seq'::regclass);
    -- ALTER TABLE ONLY fetchq_sys_metrics_writes ADD CONSTRAINT fetchq_sys_metrics_writes_pkey PRIMARY KEY (id);
    CREATE INDEX IF NOT EXISTS fetchq_sys_metrics_writes_reset_idx ON fetchq_sys_metrics_writes ( queue, metric ) WHERE ( reset IS NOT NULL );
    CREATE INDEX IF NOT EXISTS fetchq_sys_metrics_writes_increment_idx ON fetchq_sys_metrics_writes ( queue, metric ) WHERE ( increment IS NOT NULL );

    -- Maintenance Jobs
    CREATE TABLE IF NOT EXISTS fetchq_sys_jobs (
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
    CREATE UNIQUE INDEX IF NOT EXISTS fetchq_sys_jobs_task_queue_idx ON fetchq_sys_jobs USING btree (task, queue);
    CREATE INDEX IF NOT EXISTS fetchq_sys_jobs_task_idx ON fetchq_sys_jobs USING btree (task, next_iteration, iterations) WHERE (iterations < 5);

    -- add generic maintenance jobs
    INSERT INTO fetchq_sys_jobs (task, queue, next_iteration, last_iteration, attempts, iterations, settings, payload) VALUES
	('lgp', '*', NOW(), NULL, 0, 0, '{"delay":"3s", "duration":"5m"}', '{}')
	ON CONFLICT DO NOTHING;
    
    -- handle output with graceful fail support
	was_initialized = TRUE;
    EXCEPTION WHEN OTHERS THEN BEGIN
		was_initialized = FALSE;
	END;

END; $$
LANGUAGE plpgsql;
