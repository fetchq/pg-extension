
CREATE SCHEMA IF NOT EXISTS fetchq_data;
CREATE SCHEMA IF NOT EXISTS fetchq;

-- EXTENSION INFO
DROP FUNCTION IF EXISTS fetchq.info();
CREATE OR REPLACE FUNCTION fetchq.info(
    OUT version VARCHAR
) AS $$
BEGIN
	version='4.0.0';
END; $$
LANGUAGE plpgsql;
