
-- READS A SPECIFIC METRIC FOR A SPECIFIC QUEUE
DROP FUNCTION IF EXISTS fetchq_metric_get(CHARACTER VARYING, CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_metric_get (
	PAR_queue VARCHAR,
	PAR_subject VARCHAR,
	OUT current_value INTEGER,
	OUT last_update TIMESTAMP WITH TIME ZONE,
	OUT does_exists BOOLEAN
) AS $$
DECLARE
	VAR_r RECORD;
	VAR_rows INTEGER;
BEGIN
	SELECT * into VAR_r FROM fetchq_sys_metrics
	WHERE queue = PAR_queue
	AND metric = PAR_subject
	LIMIT 1;
	
	GET DIAGNOSTICS VAR_rows := ROW_COUNT;

	IF VAR_rows > 0 THEN
		current_value = VAR_r.value;
		last_update = VAR_r.updated_at;
		does_exists = true;
	END IF;
	
	IF VAR_rows = 0 THEN
		current_value = 0;
		last_update = null;
		does_exists = false;
	END IF;	
	
--	raise log '%', VAR_r.updated_at;
END; $$
LANGUAGE plpgsql;

-- READS ALL AVAILABLE METRIC FOR A QUEUE
DROP FUNCTION IF EXISTS fetchq_metric_get(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_metric_get (
	PAR_queue VARCHAR
) RETURNS TABLE (
	metric VARCHAR,
	current_value BIGINT,
	last_update TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
	RETURN QUERY
	SELECT t.metric, t.value AS current_value, t.updated_at AS last_update
	FROM fetchq_sys_metrics AS t
	WHERE queue = PAR_queue
	ORDER BY metric ASC;
END; $$
LANGUAGE plpgsql;
