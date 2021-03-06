DROP FUNCTION IF EXISTS fetchq.metric_increment(CHARACTER VARYING, CHARACTER VARYING, INTEGER);
CREATE OR REPLACE FUNCTION fetchq.metric_increment(
	PAR_queue VARCHAR,
	PAR_subject VARCHAR,
	PAR_value INTEGER,
	OUT current_value INTEGER,
	OUT was_created BOOLEAN
) AS $$
DECLARE
	updated_rows NUMERIC;
BEGIN
	was_created := false;
	current_value := 0;

	UPDATE fetchq.metrics
	SET value = value + PAR_value, updated_at = now()
	WHERE id IN(
		SELECT id FROM fetchq.metrics
		WHERE queue = PAR_queue
		AND metric = PAR_subject
		LIMIT 1
		FOR UPDATE
	)
	RETURNING value into current_value;
	GET DIAGNOSTICS updated_rows := ROW_COUNT;

	IF updated_rows = 0 THEN
		INSERT INTO fetchq.metrics
			(queue, metric, value, updated_at)
		VALUES
			(PAR_queue, PAR_subject, PAR_value, now())
		ON CONFLICT DO NOTHING
		RETURNING value into current_value;
		was_created := true;
	END IF;
END; $$
LANGUAGE plpgsql;