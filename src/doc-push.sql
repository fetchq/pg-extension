
-- PUSH A SINGLE DOCUMENT
-- SELECT * FROM "fetchq"."doc_push"('q1', 'doc1', 0, 0, NOW() + INTERVAL '1m', '{"foo": 123}');
DROP FUNCTION IF EXISTS fetchq.doc_push(CHARACTER VARYING, CHARACTER VARYING, INTEGER, INTEGER, TIMESTAMP WITH TIME ZONE, JSONB);
CREATE OR REPLACE FUNCTION fetchq.doc_push(
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
    VAR_q = FORMAT(VAR_q, PAR_queue, PAR_subject, PAR_version, PAR_priority, VAR_status, PAR_nextIteration, PAR_payload);
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

    -- handle exception
	EXCEPTION 
        WHEN sqlstate '22001' THEN
            RAISE EXCEPTION 'The subject exceeds 50 characters limit';
        WHEN OTHERS THEN BEGIN
            -- RAISE EXCEPTION '% -- %', sqlstate, SQLERRM;
            queued_docs = 0;
	END;
END; $$
LANGUAGE plpgsql;


-- queue + subject
DROP FUNCTION IF EXISTS fetchq.doc_push(CHARACTER VARYING, CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq.doc_push(
    PAR_queue VARCHAR,
    PAR_subject VARCHAR,
    OUT queued_docs INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
    VAR_status INTEGER = 0;
BEGIN
    SELECT * INTO queued_docs
    FROM fetchq.doc_push(PAR_queue, PAR_subject, 0, 0, NOW(), '{}');
END; $$
LANGUAGE plpgsql;

-- queue + subject + payload
DROP FUNCTION IF EXISTS fetchq.doc_push(CHARACTER VARYING, CHARACTER VARYING, JSONB);
CREATE OR REPLACE FUNCTION fetchq.doc_push(
    PAR_queue VARCHAR,
    PAR_subject VARCHAR,
    PAR_payload JSONB,
    OUT queued_docs INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
    VAR_status INTEGER = 0;
BEGIN
    SELECT * INTO queued_docs
    FROM fetchq.doc_push(PAR_queue, PAR_subject, 0, 0, NOW(), PAR_payload);
END; $$
LANGUAGE plpgsql;

-- queue + subject + nextIteration + payload
DROP FUNCTION IF EXISTS fetchq.doc_push(CHARACTER VARYING, CHARACTER VARYING, JSONB, TIMESTAMP WITH TIME ZONE);
CREATE OR REPLACE FUNCTION fetchq.doc_push(
    PAR_queue VARCHAR,
    PAR_subject VARCHAR,
    PAR_payload JSONB,
    PAR_nextIteration TIMESTAMP WITH TIME ZONE,
    OUT queued_docs INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
    VAR_status INTEGER = 0;
BEGIN
    SELECT * INTO queued_docs
    FROM fetchq.doc_push(PAR_queue, PAR_subject, 0, 0, PAR_nextIteration, PAR_payload);
END; $$
LANGUAGE plpgsql;