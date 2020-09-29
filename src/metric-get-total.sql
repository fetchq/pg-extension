
-- READS THE TOTAL OF A METRIC ACROSS ALL THE QUEUES
DROP FUNCTION IF EXISTS fetchq.metric_get_total(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq.metric_get_total(
	PAR_metric VARCHAR,
	OUT current_value INTEGER,
	OUT does_exists BOOLEAN
) AS $$
BEGIN
	SELECT sum(value) INTO current_value
	FROM __fetchq_metrics
	WHERE metric = PAR_metric;

	does_exists = TRUE;
	IF current_value IS NULL THEN
		current_value = 0;
		does_exists = FALSE;
	END IF;
END; $$
LANGUAGE plpgsql;
