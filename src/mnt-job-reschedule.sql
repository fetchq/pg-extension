
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
    VAR_q = VAR_q || 'UPDATE fetchq_sys_jobs SET ';
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
