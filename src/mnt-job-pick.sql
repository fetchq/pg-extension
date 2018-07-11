
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
    VAR_q = VAR_q || 'UPDATE fetchq_sys_jobs SET ';
    VAR_q = VAR_q || 'next_iteration = NOW() + ''%s'', ';
    VAR_q = VAR_q || 'attempts = attempts + 1 ';
    VAR_q = VAR_q || 'WHERE id IN (SELECT id FROM fetchq_sys_jobs WHERE attempts < 5 AND next_iteration < NOW() ORDER BY next_iteration ASC, attempts ASC LIMIT %s FOR UPDATE SKIP LOCKED) ';
    VAR_q = VAR_q || 'RETURNING *;';
    VAR_q = FORMAT(VAR_q, PAR_lockDuration, PAR_limit);
    -- RAISE NOTICE '%', VAR_q;
    RETURN QUERY EXECUTE VAR_q;
END; $$
LANGUAGE plpgsql;
