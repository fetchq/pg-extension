
DROP FUNCTION IF EXISTS fetchq_queue_create_indexes(CHARACTER VARYING, INTEGER, INTEGER);
CREATE OR REPLACE FUNCTION fetchq_queue_create_indexes (
	PAR_queue VARCHAR,
    PAR_version INTEGER,
    PAR_attempts INTEGER,
	OUT was_created BOOLEAN
) AS $$
DECLARE
	-- VAR_table_name VARCHAR = 'fetchq__';
	VAR_q VARCHAR;
BEGIN
	was_created = TRUE;

    -- index for: fetchq_doc_pick()
    VAR_q = 'CREATE INDEX IF NOT EXISTS fetchq_%s_for_pick_%s_idx ON fetchq__%s__documents ';
	VAR_q = VAR_q || '( priority DESC, next_iteration ASC, attempts ASC ) ';
    VAR_q = VAR_q || 'WHERE ( lock_upgrade IS NULL AND status = 1 AND version = %s); ';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_version, PAR_queue, PAR_version);
	EXECUTE VAR_q;

	-- index for: fetchq_mnt_make_pending()
	VAR_q = 'CREATE INDEX IF NOT EXISTS fetchq_%s_for_pnd_idx ON fetchq__%s__documents ';
	VAR_q = VAR_q || '( next_iteration ASC, attempts ASC ) ';
	VAR_q = VAR_q || 'WHERE ( lock_upgrade IS NULL AND status = 0 ); ';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue);
	EXECUTE VAR_q;

	-- index for: fetchq_mnt_reschedule_orphans()
	VAR_q = 'CREATE INDEX IF NOT EXISTS fetchq_%s_for_orp_idx ON fetchq__%s__documents ';
	VAR_q = VAR_q || '( next_iteration ASC, attempts ASC ) ';
	VAR_q = VAR_q || 'WHERE ( lock_upgrade IS NULL AND status = 2 AND attempts < %s ); ';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue, PAR_attempts);
	EXECUTE VAR_q;

	-- index for: fetchq_mnt_mark_dead()
	VAR_q = 'CREATE INDEX IF NOT EXISTS fetchq_%s_for_dod_idx ON fetchq__%s__documents ';
	VAR_q = VAR_q || '( next_iteration ASC, attempts ASC ) ';
	VAR_q = VAR_q || 'WHERE ( lock_upgrade IS NULL AND status = 2 AND attempts >= %s ); ';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue, PAR_attempts);
	EXECUTE VAR_q;

	-- index for: fetchq_doc_upsert() -- edit query
	VAR_q = 'CREATE INDEX IF NOT EXISTS fetchq_%s_for_ups_idx ON fetchq__%s__documents ';
	VAR_q = VAR_q || '( subject ) ';
	VAR_q = VAR_q || 'WHERE ( lock_upgrade IS NULL AND status <> 2 ); ';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue, PAR_attempts);
	EXECUTE VAR_q;

	EXCEPTION WHEN OTHERS THEN BEGIN
		was_created = FALSE;
	END;
END; $$
LANGUAGE plpgsql;

