
DROP FUNCTION IF EXISTS fetchq_metric_get_all();
CREATE OR REPLACE FUNCTION fetchq_metric_get_all() 
RETURNS TABLE (
	queue VARCHAR,
	cnt INTEGER,
	pnd INTEGER,
	pln INTEGER,
	act INTEGER,
	cpl INTEGER,
	kll INTEGER,
	ent INTEGER,
	drp INTEGER,
	pkd INTEGER,
	prc INTEGER,
	res INTEGER,
	rej INTEGER,
	orp INTEGER,
	err INTEGER
) AS
$BODY$
DECLARE
	VAR_q RECORD;
	VAR_c RECORD;
BEGIN
	FOR VAR_q IN
		SELECT (name) FROM fetchq_sys_queues
	LOOP
		SELECT * FROM fetchq_metric_get_common(VAR_q.name) INTO VAR_c;
		queue = VAR_q.name;
		cnt = VAR_c.cnt;
		pnd = VAR_c.pnd;
		pln = VAR_c.pln;
		act = VAR_c.act;
		cpl = VAR_c.cpl;
		kll = VAR_c.kll;
		ent = VAR_c.ent;
		pkd = VAR_c.pkd;
		prc = VAR_c.prc;
		res = VAR_c.res;
		rej = VAR_c.rej;
		orp = VAR_c.orp;
		err = VAR_c.err;
		RETURN NEXT;
	END LOOP;
END;
$BODY$
LANGUAGE plpgsql;
