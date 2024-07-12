
DROP FUNCTION IF EXISTS fetchq.upgrade__330__400();
CREATE OR REPLACE FUNCTION fetchq.upgrade__330__400(
    OUT success BOOLEAN
) AS $$
DECLARE
    VAR_r RECORD;
    VAR_q VARCHAR;
BEGIN
    -- nothing to do for this release
END; $$
LANGUAGE plpgsql;
