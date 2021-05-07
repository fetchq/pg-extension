
DROP FUNCTION IF EXISTS fetchq.upgrade__320__330();
CREATE OR REPLACE FUNCTION fetchq.upgrade__320__330(
    OUT success BOOLEAN
) AS $$
DECLARE
    VAR_q VARCHAR;
BEGIN
    ALTER TABLE "fetchq"."jobs" ALTER COLUMN "iterations" TYPE bigint;
    success = true;
END; $$
LANGUAGE plpgsql;
