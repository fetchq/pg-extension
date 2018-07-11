
-- PUSH A SINGLE DOCUMENT
DROP FUNCTION IF EXISTS fetchq_doc_push(CHARACTER VARYING, CHARACTER VARYING, INTEGER, INTEGER, TIMESTAMP WITH TIME ZONE, JSONB);
CREATE OR REPLACE FUNCTION fetchq_doc_push (
    PAR_queue VARCHAR,
    PAR_subject VARCHAR,
    PAR_version INTEGER,
    PAR_priority INTEGER,
    PAR_nextIteration TIMESTAMP WITH TIME ZONE,
    PAR_payload JSONB,
    OUT queued_docs INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
    VAR_status INTEGER = 0;
BEGIN
    -- pick right status based on nextIteration date
    IF PAR_nextIteration <= NOW() THEN
		VAR_status = 1;
	END IF;

    -- push the document into the data table
    VAR_q = 'INSERT INTO fetchq__%s__documents (';
	VAR_q = VAR_q || 'subject, version, priority, status, next_iteration, payload, created_at) VALUES (';
    VAR_q = VAR_q || '''%s'', ';
    VAR_q = VAR_q || '%s, ';
    VAR_q = VAR_q || '%s, ';
    VAR_q = VAR_q || '%s, ';
    VAR_q = VAR_q || '''%s'', ';
    VAR_q = VAR_q || '''%s'', ';
    VAR_q = VAR_q || 'NOW() ';
	VAR_q = VAR_q || ')';
    VAR_q = FORMAT(VAR_q, PAR_queue, PAR_subject, PAR_version, PAR_priority, VAR_status, PAR_nextIteration, PAR_payload);
    -- RAISE INFO '%', VAR_q;
    EXECUTE VAR_q;
    GET DIAGNOSTICS queued_docs := ROW_COUNT;

    -- update generic counters
	PERFORM fetchq_metric_log_increment(PAR_queue, 'ent', queued_docs);
	PERFORM fetchq_metric_log_increment(PAR_queue, 'cnt', queued_docs);

	-- upate version counter
	PERFORM fetchq_metric_log_increment(PAR_queue, 'v' || PAR_version::text, queued_docs);

    -- update status counter
	IF VAR_status = 1 THEN
		PERFORM fetchq_metric_log_increment(PAR_queue, 'pnd', queued_docs);
	ELSE
		PERFORM fetchq_metric_log_increment(PAR_queue, 'pln', queued_docs);
	END IF;

    -- handle exception
	EXCEPTION WHEN OTHERS THEN BEGIN
		queued_docs = 0;
	END;
END; $$
LANGUAGE plpgsql;


DROP FUNCTION IF EXISTS fetchq_doc_push(CHARACTER VARYING, INTEGER, TIMESTAMP WITH TIME ZONE, CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_doc_push (
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
	SELECT replace INTO PAR_data (PAR_data, '{DATA}', VAR_status::text || ', ' || PAR_version::text || ', ' || '''' || PAR_nextIteration::text || '''' || ', NULL, NOW()');
	VAR_q = 'INSERT INTO fetchq__%s__documents (subject, priority, payload, status, version, next_iteration, lock_upgrade, created_at) VALUES %s ON CONFLICT DO NOTHING;';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_data);
	-- RAISE INFO '%', VAR_q;
	EXECUTE VAR_q;
	GET DIAGNOSTICS queued_docs := ROW_COUNT;

	-- update generic counters
	PERFORM fetchq_metric_log_increment(PAR_queue, 'ent', queued_docs);
	PERFORM fetchq_metric_log_increment(PAR_queue, 'cnt', queued_docs);

	-- upate version counter
	PERFORM fetchq_metric_log_increment(PAR_queue, 'v' || PAR_version::text, queued_docs);

    -- update status counter
	IF VAR_status = 1 THEN
		PERFORM fetchq_metric_log_increment(PAR_queue, 'pnd', queued_docs);
	ELSE
		PERFORM fetchq_metric_log_increment(PAR_queue, 'pln', queued_docs);
	END IF;

	EXCEPTION WHEN OTHERS THEN BEGIN
		queued_docs = 0;
	END;
END; $$
LANGUAGE plpgsql;

