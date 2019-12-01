DROP SCHEMA IF EXISTS fetchq_catalog CASCADE;
CREATE SCHEMA fetchq_catalog;

CREATE OR REPLACE FUNCTION fetchq_test_init (
    OUT done BOOLEAN
) AS $$
BEGIN
    -- Cleanup hard
    DROP SCHEMA IF EXISTS fetchq_catalog CASCADE;
    DROP EXTENSION IF EXISTS fetchq CASCADE;
    DROP EXTENSION IF EXISTS "uuid-ossp";

    -- Cleanup soft
    CREATE EXTENSION IF NOT EXISTS fetchq;
    PERFORM fetchq_destroy_with_terrible_consequences();
    DROP EXTENSION fetchq CASCADE;
    CREATE EXTENSION fetchq;
    PERFORM fetchq_init();
    done = TRUE;
END; $$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fetchq_test_clean (
    OUT done BOOLEAN
) AS $$
BEGIN
    -- CREATE EXTENSION IF NOT EXISTS fetchq;
    -- PERFORM fetchq_destroy_with_terrible_consequences();
    -- DROP EXTENSION fetchq;
    done = TRUE;
END; $$
LANGUAGE plpgsql;
