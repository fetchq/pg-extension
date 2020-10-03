
DROP FUNCTION IF EXISTS fetchq.queue_truncate(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq.queue_truncate(
	PAR_queue VARCHAR,
    OUT success BOOLEAN
) AS $$
DECLARE
	VAR_tableName VARCHAR = 'fetchq_data.';
	VAR_q VARCHAR;
	VAR_r RECORD;
BEGIN

    -- return documents
	VAR_q = 'TRUNCATE fetchq_data.%s__docs RESTART IDENTITY;';
	VAR_q = FORMAT(VAR_q, PAR_queue);
	EXECUTE VAR_q;

    -- reset metrics
    PERFORM fetchq.metric_reset(PAR_queue);

    success = TRUE;
END; $$
LANGUAGE plpgsql;


DROP FUNCTION IF EXISTS fetchq.queue_truncate(CHARACTER VARYING, BOOLEAN);
CREATE OR REPLACE FUNCTION fetchq.queue_truncate(
	PAR_queue VARCHAR,
    PAR_empty BOOLEAN,
    OUT success BOOLEAN
) AS $$
DECLARE
	VAR_tableName VARCHAR = 'fetchq_data.';
	VAR_q VARCHAR;
	VAR_r RECORD;
BEGIN

    -- return documents
	VAR_q = 'TRUNCATE fetchq_data.%s__docs;';
	VAR_q = FORMAT(VAR_q, PAR_queue);
	EXECUTE VAR_q;

    IF PAR_empty THEN
        VAR_q = 'TRUNCATE fetchq_data.%s__metrics RESTART IDENTITY;';
        VAR_q = FORMAT(VAR_q, PAR_queue);
        EXECUTE VAR_q;

        VAR_q = 'TRUNCATE fetchq_data.%s__logs RESTART IDENTITY;';
        VAR_q = FORMAT(VAR_q, PAR_queue);
        EXECUTE VAR_q;

        UPDATE fetchq.jobs
        SET
            attempts = 0,
            iterations = 0,
            next_iteration = NOW(),
            last_iteration = NULL
        WHERE queue = PAR_queue;
    END IF;

    -- reset metrics
    PERFORM fetchq.metric_reset(PAR_queue);

    success = TRUE;
END; $$
LANGUAGE plpgsql;


DROP FUNCTION IF EXISTS fetchq.queue_truncate_all();
CREATE OR REPLACE FUNCTION fetchq.queue_truncate_all(
    OUT success BOOLEAN
) AS $$
DECLARE
	VAR_r RECORD;
BEGIN

    FOR VAR_r IN 
        SELECT name FROM fetchq.queues
	LOOP
        PERFORM fetchq.queue_truncate(VAR_r.name);
	END LOOP;

    success = TRUE;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq.queue_truncate_all(BOOLEAN);
CREATE OR REPLACE FUNCTION fetchq.queue_truncate_all(
    PAR_empty BOOLEAN,
    OUT success BOOLEAN
) AS $$
DECLARE
	VAR_r RECORD;
BEGIN

    FOR VAR_r IN 
        SELECT name FROM fetchq.queues
	LOOP
        PERFORM fetchq.queue_truncate(VAR_r.name, PAR_empty);
	END LOOP;

    TRUNCATE fetchq.metrics RESTART IDENTITY;
    TRUNCATE fetchq.metrics_writes RESTART IDENTITY;
    PERFORM fetchq.metric_reset_all();

    success = TRUE;
END; $$
LANGUAGE plpgsql;