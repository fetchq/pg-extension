-- @TODO: MAX ATTEMTS MUST COME FROM THE QUEUE

DROP FUNCTION IF EXISTS fetchq_doc_reject(CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING, JSONB);
CREATE OR REPLACE FUNCTION fetchq_doc_reject (
    PAR_queue VARCHAR,
    PAR_subject VARCHAR,
    PAR_message VARCHAR,
    PAR_details JSONB,
    OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
	VAR_r RECORD;
BEGIN
	-- get the current attempts limit
	VAR_q = '';
	VAR_q = VAR_q || 'SELECT max_attempts FROM fetchq_sys_queues ';
	VAR_q = VAR_q || 'WHERE name = ''%s'' LIMIT 1';
	EXECUTE FORMAT(VAR_q, PAR_queue) INTO VAR_r;

	VAR_q = 'WITH fetchq_doc_reject_lock_%s AS ( UPDATE fetchq__%s__documents AS lq SET ';
	VAR_q = VAR_q || 'status = CASE WHEN lq.attempts >= %s THEN -1 ELSE 1 END,';
	VAR_q = VAR_q || 'lock_upgrade = CASE WHEN lq.lock_upgrade IS NULL THEN NULL ELSE NOW() END,';
	VAR_q = VAR_q || 'iterations = lq.iterations + 1,';
	VAR_q = VAR_q || 'last_iteration = NOW() ';
	VAR_q = VAR_q || 'WHERE subject IN ( SELECT subject FROM fetchq__%s__documents WHERE subject = ''%s'' AND status = 2 LIMIT 1) ';
    VAR_q = VAR_q || 'RETURNING version, status, subject) ';
	VAR_q = VAR_q || 'SELECT * FROM fetchq_doc_reject_lock_%s LIMIT 1; ';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue, VAR_r.max_attempts, PAR_queue, PAR_subject, PAR_queue);

	EXECUTE VAR_q INTO VAR_r;
	GET DIAGNOSTICS affected_rows := ROW_COUNT;

    -- RAISE NOTICE 'affetced rows %', affected_rows;
    -- RAISE NOTICE '%', VAR_r;

    IF affected_rows > 0 THEN
        -- log error
        PERFORM fetchq_log_error(PAR_queue, VAR_r.subject, PAR_message, PAR_details);

        -- update metrics
        PERFORM fetchq_metric_log_increment(PAR_queue, 'prc', 1);
        PERFORM fetchq_metric_log_increment(PAR_queue, 'err', 1);
		PERFORM fetchq_metric_log_increment(PAR_queue, 'rej', 1);
		PERFORM fetchq_metric_log_decrement(PAR_queue, 'act', 1);
		IF VAR_r.status = -1 THEN
			PERFORM fetchq_metric_log_increment(PAR_queue, 'kll', 1);
		ELSE
			PERFORM fetchq_metric_log_increment(PAR_queue, 'pnd', 1);
		END IF;
    END IF;

END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_doc_reject(CHARACTER VARYING, CHARACTER VARYING, CHARACTER VARYING, JSONB, CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_doc_reject (
    PAR_queue VARCHAR,
    PAR_subject VARCHAR,
    PAR_message VARCHAR,
    PAR_details JSONB,
	PAR_refId VARCHAR,
    OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
	VAR_r RECORD;
BEGIN
	-- get the current attempts limit
	VAR_q = '';
	VAR_q = VAR_q || 'SELECT max_attempts FROM fetchq_sys_queues ';
	VAR_q = VAR_q || 'WHERE name = ''%s'' LIMIT 1';
	EXECUTE FORMAT(VAR_q, PAR_queue) INTO VAR_r;

	VAR_q = 'WITH fetchq_doc_reject_lock_%s AS ( UPDATE fetchq__%s__documents AS lq SET ';
	VAR_q = VAR_q || 'status = CASE WHEN lq.attempts >= %s THEN -1 ELSE 1 END,';
	VAR_q = VAR_q || 'lock_upgrade = CASE WHEN lq.lock_upgrade IS NULL THEN NULL ELSE NOW() END,';
	VAR_q = VAR_q || 'iterations = lq.iterations + 1,';
	VAR_q = VAR_q || 'last_iteration = NOW() ';
	VAR_q = VAR_q || 'WHERE subject IN ( SELECT subject FROM fetchq__%s__documents WHERE subject = ''%s'' AND status = 2 LIMIT 1) ';
    VAR_q = VAR_q || 'RETURNING version, status, subject) ';
	VAR_q = VAR_q || 'SELECT * FROM fetchq_doc_reject_lock_%s LIMIT 1; ';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue, VAR_r.max_attempts, PAR_queue, PAR_subject, PAR_queue);

	EXECUTE VAR_q INTO VAR_r;
	GET DIAGNOSTICS affected_rows := ROW_COUNT;

    -- RAISE NOTICE 'affetced rows %', affected_rows;
    -- RAISE NOTICE '%', VAR_r;

    IF affected_rows > 0 THEN
        -- log error
        PERFORM fetchq_log_error(PAR_queue, VAR_r.subject, PAR_message, PAR_details, PAR_refId);

        -- update metrics
        PERFORM fetchq_metric_log_increment(PAR_queue, 'prc', 1);
        PERFORM fetchq_metric_log_increment(PAR_queue, 'err', 1);
		PERFORM fetchq_metric_log_increment(PAR_queue, 'rej', 1);
		PERFORM fetchq_metric_log_decrement(PAR_queue, 'act', 1);
		IF VAR_r.status = -1 THEN
			PERFORM fetchq_metric_log_increment(PAR_queue, 'kll', 1);
		ELSE
			PERFORM fetchq_metric_log_increment(PAR_queue, 'pnd', 1);
		END IF;
    END IF;

END; $$
LANGUAGE plpgsql;
