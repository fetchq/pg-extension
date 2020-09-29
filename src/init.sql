
CREATE OR REPLACE FUNCTION fetchq.init(
    OUT was_initialized BOOLEAN
) AS $$
BEGIN
    was_initialized = TRUE;

    -- Create the FetchQ Schema
    CREATE SCHEMA IF NOT EXISTS fetchq_data;

    -- Queues Register
    CREATE TABLE IF NOT EXISTS fetchq.queues(
        id SERIAL PRIMARY KEY,
        created_at TIMESTAMP WITH TIME ZONE,
        name CHARACTER VARYING(40) NOT NULL,
        is_active BOOLEAN DEFAULT true,
        current_version INTEGER DEFAULT 0,
        max_attempts INTEGER DEFAULT 5,
        logs_retention VARCHAR(25) DEFAULT '24h',
        metrics_retention JSONB DEFAULT '[]',
        config JSONB DEFAULT '{}'
    );

    CREATE TRIGGER fetchq_trigger_sys_queues_insert AFTER INSERT OR UPDATE OR DELETE
	ON fetchq.queues
    FOR EACH ROW EXECUTE PROCEDURE fetchq.trigger_notify_as_json();

    -- Metrics Overview
    CREATE TABLE IF NOT EXISTS fetchq.metrics(
        id SERIAL PRIMARY KEY,
        queue CHARACTER VARYING(40) NOT NULL,
        metric CHARACTER VARYING(40) NOT NULL,
        value BIGINT NOT NULL,
        updated_at TIMESTAMP WITH TIME ZONE
    );

    CREATE INDEX IF NOT EXISTS __fetchq_metrics_queue_idx ON fetchq.metrics USING btree(queue);

    -- Metrics Writes
    CREATE TABLE IF NOT EXISTS fetchq.metrics_writes(
        id SERIAL PRIMARY KEY,
        created_at TIMESTAMP WITH TIME ZONE,
        queue CHARACTER VARYING(40) NOT NULL,
        metric CHARACTER VARYING(40) NOT NULL,
        increment BIGINT,
        reset BIGINT
    );

    CREATE INDEX IF NOT EXISTS __fetchq_metrics_writes_reset_idx ON fetchq.metrics_writes( queue, metric ) WHERE( reset IS NOT NULL );
    CREATE INDEX IF NOT EXISTS __fetchq_metrics_writes_increment_idx ON fetchq.metrics_writes( queue, metric ) WHERE( increment IS NOT NULL );

    -- Maintenance Jobs
    CREATE TABLE IF NOT EXISTS fetchq.jobs(
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

    -- CREATE SEQUENCE __fetchq_jobs_id_seq
    --     START WITH 1
    --     INCREMENT BY 1
    --     NO MINVALUE
    --     NO MAXVALUE
    --     CACHE 1;

    -- ALTER SEQUENCE __fetchq_jobs_id_seq OWNED BY __fetchq_jobs.id;
    -- ALTER TABLE ONLY __fetchq_jobs ALTER COLUMN id SET DEFAULT nextval('__fetchq_jobs_id_seq'::regclass);
    -- ALTER TABLE ONLY __fetchq_jobs ADD CONSTRAINT __fetchq_jobs_pkey PRIMARY KEY(id);
    CREATE UNIQUE INDEX IF NOT EXISTS __fetchq_jobs_task_queue_idx ON fetchq.jobs USING btree(task, queue);
    CREATE INDEX IF NOT EXISTS __fetchq_jobs_task_idx ON fetchq.jobs USING btree(task, next_iteration, iterations) WHERE(iterations < 5);

    -- add generic maintenance jobs
    INSERT INTO fetchq.jobs(task, queue, next_iteration, last_iteration, attempts, iterations, settings, payload) VALUES
	('lgp', '*', NOW(), NULL, 0, 0, '{"delay":"3s", "duration":"5m"}', '{}')
	ON CONFLICT DO NOTHING;
    
    -- handle output with graceful fail support
    EXCEPTION WHEN OTHERS THEN BEGIN
		was_initialized = FALSE;
	END;

END; $$
LANGUAGE plpgsql;
