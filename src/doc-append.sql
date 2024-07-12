
-- APPEND A SINGLE DOCUMENT WITH A RANDOM GENERATED SUBJECT
-- DEPENDS ON uuid-ossp EXTENSION
-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
DROP FUNCTION IF EXISTS fetchq.doc_append(CHARACTER VARYING, JSONB, INTEGER, INTEGER);
CREATE OR REPLACE FUNCTION fetchq.doc_append(
    PAR_queue VARCHAR,
    PAR_payload JSONB,
    PAR_version INTEGER,
    PAR_priority INTEGER,
    OUT subject VARCHAR
) AS $$
DECLARE
	VAR_q VARCHAR;
    VAR_queuedDocs INTEGER;
    VAR_subject VARCHAR;
    VAR_nextIteration TIMESTAMP WITH TIME ZONE = NOW();
    VAR_status INTEGER = 1;
BEGIN
    SELECT uuid_generate_v4 INTO VAR_subject from uuid_generate_v4();
    subject = VAR_subject;

    -- push the document into the data table
    VAR_q = 'INSERT INTO fetchq_data.%s__docs(';
	VAR_q = VAR_q || 'subject, version, priority, status, next_iteration, payload, created_at) VALUES(';
    VAR_q = VAR_q || '''%s'', ';
    VAR_q = VAR_q || '%s, ';
    VAR_q = VAR_q || '%s, ';
    VAR_q = VAR_q || '%s, ';
    VAR_q = VAR_q || '''%s'', ';
    VAR_q = VAR_q || '''%s'', ';
    VAR_q = VAR_q || 'NOW() ';
	VAR_q = VAR_q || ')';
    VAR_q = FORMAT(VAR_q, PAR_queue, VAR_subject, PAR_version, PAR_priority, VAR_status, VAR_nextIteration, PAR_payload);
    -- RAISE INFO '%', VAR_q;
    EXECUTE VAR_q;
    GET DIAGNOSTICS VAR_queuedDocs := ROW_COUNT;

    -- update generic counters
	PERFORM fetchq.metric_log_increment(PAR_queue, 'ent', VAR_queuedDocs);
	PERFORM fetchq.metric_log_increment(PAR_queue, 'cnt', VAR_queuedDocs);

	-- upate version counter
	PERFORM fetchq.metric_log_increment(PAR_queue, 'v' || PAR_version::text, VAR_queuedDocs);

    -- update status counter
	IF VAR_status = 1 THEN
		PERFORM fetchq.metric_log_increment(PAR_queue, 'pnd', VAR_queuedDocs);

        -- emit worker notifications
		-- IF VAR_queuedDocs > 0 THEN
		-- 	PERFORM pg_notify(FORMAT('fetchq_pnd_%s', PAR_queue), VAR_queuedDocs::text);
		-- END IF;
	ELSE
		PERFORM fetchq.metric_log_increment(PAR_queue, 'pln', VAR_queuedDocs);

        -- emit worker notifications
		-- IF VAR_queuedDocs > 0 THEN
		-- 	PERFORM pg_notify(FORMAT('fetchq_pln_%s', PAR_queue), VAR_queuedDocs::text);
		-- END IF;
	END IF;

    -- handle exception
	EXCEPTION WHEN OTHERS THEN BEGIN
		VAR_queuedDocs = 0;
        subject = NULL;
	END;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq.doc_append(CHARACTER VARYING, JSONB);
CREATE OR REPLACE FUNCTION fetchq.doc_append(
    PAR_queue VARCHAR,
    PAR_payload JSONB,
    OUT subject VARCHAR
) AS $$
BEGIN
    SELECT * INTO subject FROM fetchq.doc_append(PAR_queue, PAR_payload, 0, 0);
END; $$
LANGUAGE plpgsql;
