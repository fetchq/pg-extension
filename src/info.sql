
-- EXTENSION INFO
DROP FUNCTION IF EXISTS fetchq_info();
CREATE OR REPLACE FUNCTION fetchq_info (
    OUT version VARCHAR
) AS $$
BEGIN
	version='2.1.1';
END; $$
LANGUAGE plpgsql;
