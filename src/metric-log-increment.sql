
DROP FUNCTION IF EXISTS fetchq.metric_log_increment(CHARACTER VARYING, CHARACTER VARYING, INTEGER);
CREATE OR REPLACE FUNCTION fetchq.metric_log_increment(
	PAR_queue VARCHAR,
	PAR_subject VARCHAR,
	PAR_value INTEGER,
	OUT affected_rows INTEGER
) AS $$
BEGIN
	IF PAR_value = 0 THEN
		affected_rows = 0;
	ELSE
		INSERT INTO fetchq.metrics_writes
		( created_at, queue, metric, increment )
		VALUES
		( NOW(), PAR_queue, PAR_subject, PAR_value );
		GET DIAGNOSTICS affected_rows := ROW_COUNT;
	END IF;
END; $$
LANGUAGE plpgsql;