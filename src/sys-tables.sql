
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