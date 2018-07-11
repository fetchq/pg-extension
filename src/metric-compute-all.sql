-- SLOW QUERY!!!
-- computes and shows fresh counters from all the queues
DROP FUNCTION IF EXISTS fetchq_metric_compute_all();
CREATE OR REPLACE FUNCTION fetchq_metric_compute_all () 
RETURNS TABLE (
	queue VARCHAR,
	cnt INTEGER,
	pln INTEGER,
	pnd INTEGER,
	act INTEGER,
    cpl INTEGER,
	kll INTEGER
) AS
$BODY$
DECLARE
	VAR_q RECORD;
	VAR_c RECORD;
BEGIN
	
	FOR VAR_q IN
		SELECT (name) FROM fetchq_sys_queues
	LOOP
		SELECT * FROM fetchq_metric_compute(VAR_q.name) INTO VAR_c;
		queue = VAR_q.name;
		cnt = VAR_c.cnt;
		pln = VAR_c.pln;
		pnd = VAR_c.pnd;
		act = VAR_c.act;
        cpl = VAR_c.cpl;
		kll = VAR_c.kll;
		RETURN NEXT;
	END LOOP;
	
END;
$BODY$
LANGUAGE plpgsql;
