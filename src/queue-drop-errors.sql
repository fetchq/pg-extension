
-- DROP A QUEUE ERRORS WITH A RETENTION INTERVAL
-- returns:
-- { affected_rows: INTEGER }
DROP FUNCTION IF EXISTS fetchq_queue_drop_errors(CHARACTER VARYING, CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_queue_drop_errors (
	PAR_queue VARCHAR,
    PAR_retention VARCHAR,
	OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
	VAR_r RECORD;
BEGIN
	VAR_q = 'DELETE FROM fetchq__%s__errors WHERE created_at < NOW() - INTERVAL ''%s'';';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_retention);
	EXECUTE VAR_q;
    GET DIAGNOSTICS affected_rows := ROW_COUNT;

	EXCEPTION WHEN OTHERS THEN BEGIN
		affected_rows = 0;
	END;
END; $$
LANGUAGE plpgsql;


-- DROP A QUEUE ERRORS WITH A RETENTION DATE
-- returns:
-- { affected_rows: INTEGER }
DROP FUNCTION IF EXISTS fetchq_queue_drop_errors(CHARACTER VARYING, TIMESTAMP WITH TIME ZONE);
CREATE OR REPLACE FUNCTION fetchq_queue_drop_errors (
	PAR_queue VARCHAR,
    PAR_retention TIMESTAMP WITH TIME ZONE,
	OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
	VAR_r RECORD;
BEGIN
	VAR_q = 'DELETE FROM fetchq__%s__errors WHERE created_at < ''%s'';';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_retention);
	EXECUTE VAR_q;
    GET DIAGNOSTICS affected_rows := ROW_COUNT;

	EXCEPTION WHEN OTHERS THEN BEGIN
		affected_rows = 0;
	END;
END; $$
LANGUAGE plpgsql;


-- DROP A QUEUE ERRORS WITH A RETENTION FROM QUEUE SETTINGS
-- returns:
-- { affected_rows: INTEGER }
DROP FUNCTION IF EXISTS fetchq_queue_drop_errors(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_queue_drop_errors (
	PAR_queue VARCHAR,
	OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
	VAR_r RECORD;
    VAR_retention VARCHAR = '24h';
BEGIN
    VAR_q = 'SELECT errors_retention FROM fetchq_sys_queues WHERE name = ''%s'';';
	VAR_q = FORMAT(VAR_q, PAR_queue);
	EXECUTE VAR_q INTO VAR_r;

    -- override the default value
    IF VAR_r.errors_retention IS NOT NULL THEN
        VAR_retention = VAR_r.errors_retention;
    END IF;

    SELECT * INTO VAR_r FROM fetchq_queue_drop_errors(PAR_queue, VAR_retention);
    affected_rows = VAR_r.affected_rows;

	EXCEPTION WHEN OTHERS THEN BEGIN
		affected_rows = 0;
	END;
END; $$
LANGUAGE plpgsql;
