
DROP FUNCTION IF EXISTS fetchq.upgrade__310__320();
CREATE OR REPLACE FUNCTION fetchq.upgrade__310__320(
    OUT success BOOLEAN
) AS $$
DECLARE
    VAR_q VARCHAR;
BEGIN
    -- temporary cast integers to strings:
    ALTER TABLE "fetchq"."metrics_writes" 
    ALTER COLUMN "id" SET DATA TYPE VARCHAR(36),
    ALTER COLUMN "id" SET DEFAULT uuid_generate_v1();

    -- update the existing lines to use uuids:
    UPDATE "fetchq"."metrics_writes" SET "id" = uuid_generate_v1();

    -- cast the string type to be uuid:
    ALTER TABLE "fetchq"."metrics_writes"
    ALTER COLUMN "id" SET DATA TYPE UUID USING "id"::UUID,
    ALTER COLUMN "id" SET DEFAULT uuid_generate_v1();

    -- drop the integer sequence:
    DROP SEQUENCE IF EXISTS "fetchq"."metrics_writes_id_seq" CASCADE;

    success = true;
END; $$
LANGUAGE plpgsql;
