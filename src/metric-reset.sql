
-- SLOW QUERY!
-- compute and resets all the basic counters for a queue metrics
DROP FUNCTION IF EXISTS fetchq_metric_reset(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_metric_reset (
	PAR_queue VARCHAR,
	OUT cnt INTEGER,
	OUT pln INTEGER,
	OUT pnd INTEGER,
	OUT act INTEGER,
    OUT cpl INTEGER,
	OUT kll INTEGER
) AS
$BODY$
DECLARE
	VAR_res RECORD;
BEGIN
	SELECT * INTO VAR_res FROM fetchq_metric_compute(PAR_queue);
	
	PERFORM fetchq_metric_set(PAR_queue, 'cnt', VAR_res.cnt);
	PERFORM fetchq_metric_set(PAR_queue, 'pln', VAR_res.pln);
	PERFORM fetchq_metric_set(PAR_queue, 'pnd', VAR_res.pnd);
	PERFORM fetchq_metric_set(PAR_queue, 'act', VAR_res.act);
    PERFORM fetchq_metric_set(PAR_queue, 'cpl', VAR_res.cpl);
	PERFORM fetchq_metric_set(PAR_queue, 'kll', VAR_res.kll);
	
	-- forward data out
	cnt = VAR_res.cnt;
	pln = VAR_res.pln;
	pnd = VAR_res.pnd;
	act = VAR_res.act;
    cpl = VAR_res.cpl;
	kll = VAR_res.kll;

END;
$BODY$
LANGUAGE plpgsql;

