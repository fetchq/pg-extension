
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
