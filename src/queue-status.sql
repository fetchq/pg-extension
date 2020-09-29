
DROP FUNCTION IF EXISTS fetchq_catalog.fetchq_queue_status();
CREATE OR REPLACE FUNCTION fetchq_catalog.fetchq_queue_status() RETURNS TABLE(
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

DROP FUNCTION IF EXISTS fetchq_catalog.fetchq_queue_status(VARCHAR);
CREATE OR REPLACE FUNCTION fetchq_catalog.fetchq_queue_status(
    PAR_queue VARCHAR
) RETURNS TABLE(
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
