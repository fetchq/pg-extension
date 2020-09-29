
-- EXTENSION INFO
DROP FUNCTION IF EXISTS fetchq_info();
CREATE OR REPLACE FUNCTION fetchq_info(
    OUT version VARCHAR
) AS $$
BEGIN
	version='3.0.0';
END; $$
LANGUAGE plpgsql;
