
DROP FUNCTION IF EXISTS fetchq_queue_drop_version(CHARACTER VARYING, INTEGER);
CREATE OR REPLACE FUNCTION fetchq_queue_drop_version (
	PAR_queue VARCHAR,
	PAR_oldVersion INTEGER,
	OUT was_dropped BOOLEAN
) AS $$
DECLARE
	VAR_q VARCHAR;
	VAR_r RECORD;
BEGIN
	-- initial values
	was_dropped = true;

	-- @TODO: check that this is not the current index
	VAR_q = '';
	VAR_q = VAR_q || 'SELECT id FROM fetchq_sys_queues ';
	VAR_q = VAR_q || 'WHERE name = ''%s'' AND current_version = %s';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_oldVersion);
	EXECUTE VAR_q INTO VAR_r;

    IF VAR_r.id IS NOT NULL THEN
        RAISE EXCEPTION 'can not drop current version: %', PAR_oldVersion;
    END IF;

	-- drop old index
	VAR_q = 'DROP INDEX IF EXISTS fetchq_%s_for_pick_%s_idx';
	EXECUTE FORMAT(VAR_q, PAR_queue, PAR_oldVersion);

	EXCEPTION WHEN OTHERS THEN BEGIN
		was_dropped = false;
	END;
END; $$
LANGUAGE plpgsql;
