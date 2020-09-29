
-- CREATED A QUEUE
-- returns:
-- { was_created: TRUE }
DROP FUNCTION IF EXISTS fetchq.queue_create(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq.queue_create(
	PAR_queue VARCHAR,
	OUT was_created BOOLEAN,
	OUT queue_id INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
BEGIN
	was_created = TRUE;

	-- pick the queue id, it creates the queue's index entry if doesn't exists already
	SELECT t.queue_id INTO queue_id FROM fetchq.queue_get_id(PAR_queue) AS t;

	VAR_q = 'CREATE TABLE fetchq_data.%s__documents (';
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
	VAR_q = 'CREATE TABLE fetchq_data.%s__logs (';
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
	VAR_q = 'CREATE TABLE fetchq_data.%s__metrics (';
	VAR_q = VAR_q || 'id SERIAL PRIMARY KEY,';
	VAR_q = VAR_q || 'created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),';
	VAR_q = VAR_q || 'metric CHARACTER VARYING(50) NOT NULL,';
	VAR_q = VAR_q || 'value bigint';
	VAR_q = VAR_q || ');';
	VAR_q = FORMAT(VAR_q, PAR_queue);
	EXECUTE VAR_q;

	-- add indexes to the table
	PERFORM fetchq.queue_create_indexes(PAR_queue);
	
	-- enable notifications
	-- (slows down by half insert performance!)
	-- PERFORM fetchq_queue_enable_notify(PAR_queue);

	-- add new maintenance tasks
	INSERT INTO fetchq.jobs (task, queue, next_iteration, last_iteration, attempts, iterations, settings, payload) VALUES
	('mnt', PAR_queue, NOW(), NULL, 0, 0, '{"delay":"1m", "duration":"5m", "limit":500}', '{}'),
	('sts', PAR_queue, NOW(), NULL, 0, 0, '{"delay":"1m", "duration":"5m"}', '{}'),
	('cmp', PAR_queue, NOW(), NULL, 0, 0, '{"delay":"1m", "duration":"5m"}', '{}'),
	('drp', PAR_queue, NOW(), NULL, 0, 0, '{"delay":"1m", "duration":"5m"}', '{}')
	ON CONFLICT DO NOTHING;

	-- send out notifications
	PERFORM pg_notify('fetchq_queue_create', PAR_queue);

	EXCEPTION WHEN OTHERS THEN BEGIN
		was_created = FALSE;
	END;
END; $$
LANGUAGE plpgsql;
