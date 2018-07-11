-- SLOW QUERY!!!
-- calculates the real queue metrics by running real count(*) operations
-- on the target queue table:
-- select * from fetchq_metric_compute('is_prf');
--
-- NOTE: this is real slow query!
-- better put the entire system in pause before you run this one
DROP FUNCTION IF EXISTS fetchq_metric_compute(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_metric_compute (
	PAR_queue VARCHAR,
	OUT cnt INTEGER,
	OUT pln INTEGER,
	OUT pnd INTEGER,
	OUT act INTEGER,
	OUT kll INTEGER,
	OUT cpl INTEGER
) AS
$BODY$
DECLARE
	VAR_q1 CONSTANT VARCHAR := 'SELECT COUNT(subject) FROM fetchq__%s__documents';
	VAR_q2 CONSTANT VARCHAR := 'SELECT COUNT(subject) FROM fetchq__%s__documents WHERE STATUS = %s';
BEGIN
	cnt = 0;
	pln = 0;
	pnd = 0;
	act = 0;
	kll = 0;
	cpl = 0;
	
	EXECUTE FORMAT(VAR_q1, PAR_queue) INTO cnt;
	EXECUTE FORMAT(VAR_q2, PAR_queue, -1) INTO kll;
	EXECUTE FORMAT(VAR_q2, PAR_queue, 0) INTO pln;
	EXECUTE FORMAT(VAR_q2, PAR_queue, 1) INTO pnd;
	EXECUTE FORMAT(VAR_q2, PAR_queue, 3) INTO cpl;
END;
$BODY$
LANGUAGE plpgsql;
