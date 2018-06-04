
-- create tables
CREATE TABLE fetchq_sys_queues (
    id bigint NOT NULL,
    name character varying(15) NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone,
    config jsonb default '{}'
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
