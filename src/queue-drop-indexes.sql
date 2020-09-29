
DROP FUNCTION IF EXISTS fetchq_catalog.fetchq_queue_drop_indexes(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_catalog.fetchq_queue_drop_indexes(
	PAR_queue VARCHAR,
	OUT was_dropped BOOLEAN
) AS $$
DECLARE
	-- VAR_table_name VARCHAR = 'fetchq__';
	VAR_q VARCHAR;
    VAR_r RECORD;
BEGIN
	was_dropped = TRUE;

    --(select 'foo' as name)
    SELECT current_version INTO VAR_r FROM fetchq_catalog.fetchq_sys_queues WHERE name = PAR_queue;
    -- -- index for: fetchq_catalog.fetchq_doc_pick()
    -- VAR_q = 'SELECT current_version INTO VAR_r FROM fetchq_catalog.fetchq_sys_queues WHERE name = ''%s'';';
    -- VAR_q = FORMAT(VAR_q, PAR_queue);
    -- EXECUTE VAR_q;

    VAR_q = 'DROP INDEX IF EXISTS fetchq_catalog.fetchq_%s_for_pick_%s_idx;';
	VAR_q = FORMAT(VAR_q, PAR_queue, VAR_r.current_version);
	EXECUTE VAR_q;

	-- index for: fetchq_catalog.fetchq_mnt_make_pending()
	VAR_q = 'DROP INDEX IF EXISTS fetchq_catalog.fetchq_%s_for_pnd_idx;';
	VAR_q = FORMAT(VAR_q, PAR_queue);
	EXECUTE VAR_q;

	-- index for: fetchq_catalog.fetchq_mnt_reschedule_orphans()
	VAR_q = 'DROP INDEX IF EXISTS fetchq_catalog.fetchq_%s_for_orp_idx;';
	VAR_q = FORMAT(VAR_q, PAR_queue);
	EXECUTE VAR_q;

	-- index for: fetchq_catalog.fetchq_mnt_mark_dead()
	VAR_q = 'DROP INDEX IF EXISTS fetchq_catalog.fetchq_%s_for_dod_idx;';
	VAR_q = FORMAT(VAR_q, PAR_queue);
	EXECUTE VAR_q;

	-- index for: fetchq_catalog.fetchq_doc_upsert() -- edit query
	VAR_q = 'DROP INDEX IF EXISTS fetchq_catalog.fetchq_%s_for_ups_idx;';
	VAR_q = FORMAT(VAR_q, PAR_queue);
	EXECUTE VAR_q;

	EXCEPTION WHEN OTHERS THEN BEGIN
		was_dropped = FALSE;
	END;
END; $$
LANGUAGE plpgsql;

