DROP FUNCTION IF EXISTS fetchq_metric_log_set(CHARACTER VARYING, CHARACTER VARYING, INTEGER);
CREATE OR REPLACE FUNCTION fetchq_metric_log_set (
	PAR_queue VARCHAR,
	PAR_subject VARCHAR,
	PAR_value INTEGER,
	OUT affected_rows INTEGER
) AS $$
BEGIN
	INSERT INTO fetchq_sys_metrics_writes
	( created_at, queue, metric, reset )
	VALUES
	( NOW(), PAR_queue, PAR_subject, PAR_value );
	GET DIAGNOSTICS affected_rows := ROW_COUNT;
END; $$
LANGUAGE plpgsql;