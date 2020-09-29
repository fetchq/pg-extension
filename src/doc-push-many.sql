-- PUSH MANY DOCUMENTS
DROP FUNCTION IF EXISTS fetchq.doc_push(CHARACTER VARYING, INTEGER, TIMESTAMP WITH TIME ZONE, CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq.doc_push(
	PAR_queue VARCHAR,
	PAR_version INTEGER,
	PAR_nextIteration TIMESTAMP WITH TIME ZONE,
	PAR_data VARCHAR,
	OUT queued_docs INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
	VAR_status INTEGER = 0;
BEGIN
    -- pick right status based on nextIteration date
	IF PAR_nextIteration <= now() THEN
		VAR_status = 1;
	END IF;

    -- push the documents into the data table
	SELECT replace INTO PAR_data(PAR_data, '{DATA}', VAR_status::text || ', ' || PAR_version::text || ', ' || '''' || PAR_nextIteration::text || '''' || ', NULL, NOW()');
	VAR_q = 'INSERT INTO fetchq_catalog.%s__documents(subject, priority, payload, status, version, next_iteration, lock_upgrade, created_at) VALUES %s ON CONFLICT DO NOTHING;';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_data);
	-- RAISE INFO '%', VAR_q;
	EXECUTE VAR_q;
	GET DIAGNOSTICS queued_docs := ROW_COUNT;

	-- update generic counters
	PERFORM fetchq.metric_log_increment(PAR_queue, 'ent', queued_docs);
	PERFORM fetchq.metric_log_increment(PAR_queue, 'cnt', queued_docs);

	-- upate version counter
	PERFORM fetchq.metric_log_increment(PAR_queue, 'v' || PAR_version::text, queued_docs);

    -- update status counter
	IF VAR_status = 1 THEN
		PERFORM fetchq.metric_log_increment(PAR_queue, 'pnd', queued_docs);

		-- emit worker notifications
		-- IF queued_docs > 0 THEN
		-- 	PERFORM pg_notify(FORMAT('fetchq_pnd_%s', PAR_queue), queued_docs::text);
		-- END IF;
	ELSE
		PERFORM fetchq.metric_log_increment(PAR_queue, 'pln', queued_docs);

        -- emit worker notifications
		-- IF queued_docs > 0 THEN
		-- 	PERFORM pg_notify(FORMAT('fetchq_pln_%s', PAR_queue), queued_docs::text);
		-- END IF;
	END IF;

	EXCEPTION WHEN OTHERS THEN BEGIN
		queued_docs = 0;
	END;
END; $$
LANGUAGE plpgsql;


