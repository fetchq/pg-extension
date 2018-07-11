
-- DROP RECORDS FROM A GENERIC TIMESERIE TABLE
-- select (*) from lock_queue_drop_time( 'targetTable', 'timeField', 'retainAmount', 'older date', 'newer date')
-- retainAmount: microseconds | milliseconds | second | minute | hour | day | week | month | quarter | year | decade | century | millennium
DROP FUNCTION IF EXISTS fetchq_utils_ts_retain(character varying, character varying, character varying, timestamp with time zone, timestamp with time zone);
CREATE OR REPLACE FUNCTION fetchq_utils_ts_retain (
	tableName VARCHAR,
	fieldName VARCHAR,
	retainStr VARCHAR,
	intervalStart TIMESTAMP WITH TIME ZONE,
	intervalEnd TIMESTAMP WITH TIME ZONE,
	OUT removed_rows BIGINT
) AS $$
DECLARE
	q VARCHAR;
BEGIN

	q = 'DELETE FROM %s ';
	q = q || 'WHERE %s BETWEEN (''%s'') AND (''%s'') ';
	q = q || 'AND id NOT IN ( ';
	q = q || 'SELECT id FROM ( ';
	q = q || 'SELECT DISTINCT ON (lq_retention_fld) id, date_trunc(''%s'', %s) lq_retention_fld FROM %s ';
	q = q || 'WHERE %s BETWEEN (''%s'') AND (''%s'') ';
	q = q || 'ORDER BY lq_retention_fld, %s DESC ';
	q = q || ') AS lock_queue_drop_time_get_retained_ids';
	q = q || ') RETURNING id;';
	q = FORMAT(q, tableName, fieldName, intervalStart, intervalEnd, retainStr, fieldName, tableName, fieldName, intervalStart, intervalEnd, fieldName);

--	raise log '%', q;

	EXECUTE q;
	GET DIAGNOSTICS removed_rows := ROW_COUNT;
END; $$
LANGUAGE plpgsql;