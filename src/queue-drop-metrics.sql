
-- DROP A QUEUE ERRORS WITH A RETENTION INTERVAL
-- returns:
-- { affected_rows: INTEGER }
DROP FUNCTION IF EXISTS fetchq_queue_drop_metrics(CHARACTER VARYING, JSONB);
CREATE OR REPLACE FUNCTION fetchq_queue_drop_metrics (
	PAR_queue VARCHAR,
    PAR_config JSONB,
	OUT removed_rows INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
	VAR_r RECORD;
    VAR_rowSrc TEXT;
    VAR_rowCfg RECORD;
    VAR_rowRes RECORD;
BEGIN
    removed_rows = 0;
    -- RAISE NOTICE '%', PAR_config;

    FOR VAR_r IN SELECT value::jsonb FROM jsonb_array_elements(PAR_config)
    LOOP
        VAR_rowSrc = VAR_r.value;
        VAR_rowSrc = REPLACE(VAR_rowSrc, 'from', 'a' );
        VAR_rowSrc = REPLACE(VAR_rowSrc, 'to', 'b' );
        VAR_rowSrc = REPLACE(VAR_rowSrc, 'retain', 'c' );
        select * INTO VAR_rowCfg from jsonb_to_record(VAR_rowSrc::jsonb) as x(a text, b text, c text);
        -- RAISE NOTICE 'from: %, to: %, retain: %', VAR_rowCfg.a, VAR_rowCfg.b, VAR_rowCfg.c;

        VAR_q = 'SELECT * FROM fetchq_utils_ts_retain(''fetchq__%s__metrics'', ''created_at'', ''%s'', NOW() - INTERVAL ''%s'', NOW() - INTERVAL ''%s'')';
        VAR_q = FORMAT(VAR_q, PAR_queue, VAR_rowCfg.c, VAR_rowCfg.a, VAR_rowCfg.b);
        -- RAISE NOTICE '%', VAR_q;
        EXECUTE VAR_q INTO VAR_rowRes;

        removed_rows = removed_rows + VAR_rowRes.removed_rows;
    END LOOP;

    -- RAISE NOTICE 'removed roes %', removed_rows;
	EXCEPTION WHEN OTHERS THEN BEGIN
		removed_rows = 0;
	END;
END; $$
LANGUAGE plpgsql;


DROP FUNCTION IF EXISTS fetchq_queue_drop_metrics(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_queue_drop_metrics (
	PAR_queue VARCHAR,
	OUT removed_rows INTEGER
) AS $$
DECLARE
	VAR_q VARCHAR;
	VAR_r RECORD;
    VAR_retention VARCHAR = '[]';
BEGIN
    
    VAR_q = 'SELECT metrics_retention FROM fetchq_sys_queues WHERE name = ''%s'';';
	VAR_q = FORMAT(VAR_q, PAR_queue);
	EXECUTE VAR_q INTO VAR_r;

    -- override the default value
    IF VAR_r.metrics_retention IS NOT NULL THEN
        VAR_retention = VAR_r.metrics_retention;
    END IF;

    RAISE NOTICE 'retention %', VAR_retention;

    -- run the operation
    SELECT * INTO VAR_r FROM fetchq_queue_drop_metrics(PAR_queue, VAR_retention::jsonb);
    removed_rows = VAR_r.removed_rows;

    -- RAISE NOTICE 'removed roes %', removed_rows;
	EXCEPTION WHEN OTHERS THEN BEGIN
		removed_rows = 0;
	END;
END; $$
LANGUAGE plpgsql;
