
DROP FUNCTION IF EXISTS fetchq_metric_snap(CHARACTER VARYING, CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_metric_snap (
	PAR_queue VARCHAR,
	PAR_metric VARCHAR,
	OUT success BOOLEAN,
    OUT inserts INTEGER
) AS $$
DECLARE
    VAR_r RECORD;
    VAR_q VARCHAR;
BEGIN
	success = true;
    SELECT * INTO VAR_r FROM fetchq_metric_get(PAR_queue, PAR_metric);
    RAISE NOTICE '%', VAR_r.current_value;

    VAR_q = 'INSERT INTO fetchq__%s__metrics ';
	VAR_q = VAR_q || '( metric,  value) VALUES ';
	VAR_q = VAR_q || '( ''%s'',  %s );';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_metric, VAR_r.current_value);
	EXECUTE VAR_q;
    GET DIAGNOSTICS inserts := ROW_COUNT;

    -- RAISE EXCEPTION 'foo';
    EXCEPTION WHEN OTHERS THEN BEGIN
        success = false;
    END;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_metric_snap(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_metric_snap (
	PAR_queue VARCHAR,
	OUT success BOOLEAN,
    OUT inserts INTEGER
) AS $$
DECLARE
    VAR_q VARCHAR;
BEGIN
	success = true;

    VAR_q = 'INSERT INTO fetchq__%s__metrics ( metric,  value)';
	VAR_q = VAR_q || 'SELECT metric, current_value AS value ';
	VAR_q = VAR_q || 'FROM fetchq_metric_get(''%s'')';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue);
	EXECUTE VAR_q;
    GET DIAGNOSTICS inserts := ROW_COUNT;

    -- RAISE EXCEPTION 'foo';
    EXCEPTION WHEN OTHERS THEN BEGIN
        success = false;
    END;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_metric_snap(CHARACTER VARYING, JSONB);
CREATE OR REPLACE FUNCTION fetchq_metric_snap (
	PAR_queue VARCHAR,
    PAR_whiteList JSONB,
	OUT success BOOLEAN,
    OUT inserts INTEGER
) AS $$
DECLARE
    VAR_q VARCHAR;
    VAR_r RECORD;
BEGIN
	success = true;

    VAR_q = 'INSERT INTO fetchq__%s__metrics ( metric,  value)';
	VAR_q = VAR_q || 'SELECT metric, current_value AS value ';
	VAR_q = VAR_q || 'FROM fetchq_metric_get(''%s'') AS metrics ';
	VAR_q = VAR_q || 'INNER JOIN (SELECT value::varchar FROM jsonb_array_elements_text(''%s'')) ';
	VAR_q = VAR_q || 'AS filters ON metrics.metric = filters.value;';
	VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue, PAR_whiteList);
	EXECUTE VAR_q;
    GET DIAGNOSTICS inserts := ROW_COUNT;

    EXCEPTION WHEN OTHERS THEN BEGIN
        success = false;
    END;
END; $$
LANGUAGE plpgsql;