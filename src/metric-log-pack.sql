DROP FUNCTION IF EXISTS fetchq_metric_log_pack();
CREATE OR REPLACE FUNCTION fetchq_metric_log_pack (
	OUT affected_rows INTEGER
) AS $$
DECLARE
	VAR_r RECORD;
	VAR_sum INTEGER;
BEGIN

	-- fetch data to work on from the writes log
	CREATE TEMP TABLE fetchq_sys_metrics_writes_pack ON COMMIT DROP
	AS SELECT * FROM fetchq_sys_metrics_writes WHERE created_at <= NOW();

	-- reset counters to current value
	FOR VAR_r IN
		SELECT DISTINCT ON (queue, metric) id, queue, metric, reset
		FROM fetchq_sys_metrics_writes_pack
		WHERE reset IS NOT NULL
		ORDER BY queue, metric, created_at DESC
	LOOP
		PERFORM fetchq_metric_set(VAR_r.queue, VAR_r.metric, VAR_r.reset::integer);
	END LOOP;

	-- aggregate the rest of increments
	FOR VAR_r IN
		SELECT DISTINCT ON (queue, metric) id, queue, metric, increment
		FROM fetchq_sys_metrics_writes_pack
		WHERE increment IS NOT NULL
		ORDER BY queue, metric, created_at ASC
	LOOP
		SELECT SUM(increment) INTO VAR_sum
		FROM fetchq_sys_metrics_writes_pack
		WHERE queue = VAR_r.queue
		AND metric = VAR_r.metric
		AND increment IS NOT NULL;

		PERFORM fetchq_metric_increment(VAR_r.queue, VAR_r.metric, VAR_sum);
	END LOOP;

	-- drop records that have been worked out
	DELETE FROM fetchq_sys_metrics_writes WHERE id IN
	(SELECT id FROM fetchq_sys_metrics_writes_pack);
	GET DIAGNOSTICS affected_rows := ROW_COUNT;

	-- forcefully drop the temp table;
	DROP TABLE fetchq_sys_metrics_writes_pack;

END; $$
LANGUAGE plpgsql;