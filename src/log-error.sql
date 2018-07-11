
DROP FUNCTION IF EXISTS fetchq_log_error(CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING, JSONB);
CREATE OR REPLACE FUNCTION fetchq_log_error (
    PAR_queue VARCHAR,
    PAR_subject VARCHAR,
    PAR_message VARCHAR,
    PAR_details JSONB,
    OUT queued_logs BOOLEAN
) AS $$
DECLARE
    VAR_q VARCHAR;
BEGIN

    VAR_q = 'INSERT INTO fetchq__%s__errors (';
	VAR_q = VAR_q || 'created_at, subject, message, details';
    VAR_q = VAR_q || ') VALUES (';
    VAR_q = VAR_q || 'NOW(), ';
    VAR_q = VAR_q || '''%s'', ';
    VAR_q = VAR_q || '''%s'', ';
    VAR_q = VAR_q || '''%s'' ';
	VAR_q = VAR_q || ')';
    VAR_q = FORMAT(VAR_q, PAR_queue, PAR_subject, PAR_message, PAR_details);

    EXECUTE VAR_q;
    GET DIAGNOSTICS queued_logs := ROW_COUNT;

    -- handle exception
	EXCEPTION WHEN OTHERS THEN BEGIN
		queued_logs = 0;
	END;
END; $$
LANGUAGE plpgsql;


DROP FUNCTION IF EXISTS fetchq_log_error(CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING, JSONB, VARCHAR);
CREATE OR REPLACE FUNCTION fetchq_log_error (
    PAR_queue VARCHAR,
    PAR_subject VARCHAR,
    PAR_message VARCHAR,
    PAR_details JSONB,
    PAR_refId VARCHAR,
    OUT queued_logs BOOLEAN
) AS $$
DECLARE
    VAR_q VARCHAR;
BEGIN

    VAR_q = 'INSERT INTO fetchq__%s__errors (';
	VAR_q = VAR_q || 'created_at, subject, message, details, ref_id';
    VAR_q = VAR_q || ') VALUES (';
    VAR_q = VAR_q || 'NOW(), ';
    VAR_q = VAR_q || '''%s'', ';
    VAR_q = VAR_q || '''%s'', ';
    VAR_q = VAR_q || '''%s'', ';
    VAR_q = VAR_q || '''%s'' ';
	VAR_q = VAR_q || ')';
    VAR_q = FORMAT(VAR_q, PAR_queue, PAR_subject, PAR_message, PAR_details, PAR_refId);

    EXECUTE VAR_q;
    GET DIAGNOSTICS queued_logs := ROW_COUNT;

    -- handle exception
	EXCEPTION WHEN OTHERS THEN BEGIN
		queued_logs = 0;
	END;
END; $$
LANGUAGE plpgsql;
