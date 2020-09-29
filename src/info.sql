
-- EXTENSION INFO
DROP FUNCTION IF EXISTS fetchq.info();
CREATE OR REPLACE FUNCTION fetchq.info(
    OUT version VARCHAR
) AS $$
BEGIN
	version='3.0.0';
END; $$
LANGUAGE plpgsql;
