-- GET ALL COMMOMN METRICS FOR A SPECIFIC QUEUE
DROP FUNCTION IF EXISTS fetchq_metric_get_common(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_metric_get_common(
	PAR_queue VARCHAR,
	OUT cnt INTEGER,
	OUT pnd INTEGER,
	OUT pln INTEGER,
	OUT act INTEGER,
	OUT cpl INTEGER,
	OUT kll INTEGER,
	OUT ent INTEGER,
	OUT drp INTEGER,
	OUT pkd INTEGER,
	OUT prc INTEGER,
	OUT res INTEGER,
	OUT rej INTEGER,
	OUT orp INTEGER,
	OUT err INTEGER
) AS
$BODY$
DECLARE
	VAR_q RECORD;
	VAR_c RECORD;
BEGIN
	FOR VAR_q IN
		SELECT * FROM fetchq_metric_get(PAR_queue)
	LOOP
		IF VAR_q.metric = 'cnt' THEN cnt = VAR_q.current_value; END IF;
		IF VAR_q.metric = 'pnd' THEN pnd = VAR_q.current_value; END IF;
		IF VAR_q.metric = 'pln' THEN pln = VAR_q.current_value; END IF;
		IF VAR_q.metric = 'act' THEN act = VAR_q.current_value; END IF;
		IF VAR_q.metric = 'cpl' THEN cpl = VAR_q.current_value; END IF;
		IF VAR_q.metric = 'kll' THEN kll = VAR_q.current_value; END IF;
		IF VAR_q.metric = 'ent' THEN ent = VAR_q.current_value; END IF;
		IF VAR_q.metric = 'drp' THEN drp = VAR_q.current_value; END IF;
		IF VAR_q.metric = 'pkd' THEN pkd = VAR_q.current_value; END IF;
		IF VAR_q.metric = 'prc' THEN prc = VAR_q.current_value; END IF;
		IF VAR_q.metric = 'res' THEN res = VAR_q.current_value; END IF;
		IF VAR_q.metric = 'rej' THEN rej = VAR_q.current_value; END IF;
		IF VAR_q.metric = 'orp' THEN orp = VAR_q.current_value; END IF;
		IF VAR_q.metric = 'err' THEN err = VAR_q.current_value; END IF;
	END LOOP;
END;
$BODY$
LANGUAGE plpgsql;
