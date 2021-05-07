
DROP FUNCTION IF EXISTS fetchq.upgrade__320__330();
CREATE OR REPLACE FUNCTION fetchq.upgrade__320__330(
    OUT success BOOLEAN
) AS $$
DECLARE
    VAR_r RECORD;
    VAR_q VARCHAR;
BEGIN
    -- Update jobs queue iterations counters
    ALTER TABLE "fetchq"."jobs" ALTER COLUMN "iterations" TYPE bigint;
    success = true;

    -- Update existing queues
    FOR VAR_r IN
		SELECT("name") FROM "fetchq"."queues"
	LOOP
        VAR_q = 'ALTER TABLE "fetchq_data"."%s__docs" ALTER COLUMN "iterations" TYPE BIGINT';
        VAR_q = FORMAT(VAR_q, VAR_r.name);
	    EXECUTE VAR_q;
	END LOOP;

END; $$
LANGUAGE plpgsql;
