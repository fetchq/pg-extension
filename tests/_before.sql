-- INITIALIZE THE WHOLE TEST RUN
-- cleanup db from previous state

DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;

DROP SCHEMA IF EXISTS fetchq CASCADE;
CREATE SCHEMA fetchq;

DROP SCHEMA IF EXISTS fetchq_data CASCADE;
CREATE SCHEMA fetchq_data;

DROP SCHEMA IF EXISTS fetchq_test CASCADE;
CREATE SCHEMA fetchq_test;

-- Called at the beginning of every test case
CREATE OR REPLACE FUNCTION fetchq_test.__beforeEach(
    OUT done BOOLEAN
) 
SET client_min_messages = error
AS $$
BEGIN
    -- Cleanup previous state
    DROP SCHEMA IF EXISTS fetchq CASCADE;
    DROP SCHEMA IF EXISTS fetchq_data CASCADE;
    DROP EXTENSION IF EXISTS fetchq CASCADE;
    DROP EXTENSION IF EXISTS "uuid-ossp";

    -- Prepare current state
    CREATE SCHEMA IF NOT EXISTS fetchq;
    CREATE SCHEMA IF NOT EXISTS fetchq_data;
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION fetchq;

    PERFORM fetchq.init();
    done = TRUE;
END; $$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fetchq_test.__afterEach(
    OUT done BOOLEAN
) 
SET client_min_messages = error
AS $$
BEGIN
    -- Cleanup previous state
    -- No need, a new test will cleanup in the "beforeEach"
    -- DROP SCHEMA IF EXISTS fetchq CASCADE;
    -- DROP SCHEMA IF EXISTS fetchq_data CASCADE;
    -- DROP EXTENSION IF EXISTS fetchq CASCADE;
    -- DROP EXTENSION IF EXISTS "uuid-ossp";
    done = TRUE;
END; $$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fetchq_test.__run(
    PAR_testName VARCHAR,
    PAR_testAssert VARCHAR,
    OUT done BOOLEAN
) 
AS $$
DECLARE
	VAR_q VARCHAR;
    VAR_errMessage TEXT;
    VAR_errDetails TEXT;
    VAR_errHint TEXT;
BEGIN

    -- Cleanup BEFORE test execution
    PERFORM fetchq_test.__beforeEach();

    -- Prepare test statement
    VAR_q = 'SELECT * FROM fetchq_test.';
	VAR_q = VAR_q || PAR_testName;
	VAR_q = VAR_q || '();';
	VAR_q = FORMAT(VAR_q, PAR_testName);

    -- Try/catch the test and present a nice error message
    BEGIN
        RAISE NOTICE '>>> [RUN] %', PAR_testName;
        EXECUTE VAR_q;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS VAR_errMessage = MESSAGE_TEXT,
                                VAR_errDetails = PG_EXCEPTION_DETAIL,
                                VAR_errHint = PG_EXCEPTION_HINT;
        RAISE EXCEPTION E'



##########################
### FETCHQ TEST FAILED ###
##########################

TEST:
> fetchq_test.%()
%

ERROR:
%
%

DETAILS:
%



'
, PAR_testName, PAR_testAssert, VAR_errMessage, VAR_errHint, VAR_errDetails;
    END;

    -- Cleanup AFTER test execution
    PERFORM fetchq_test.__afterEach();
    
    done = TRUE;
END; $$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fetchq_test.expect_equalInt(
    VAR_received INTEGER,
    VAR_expected INTEGER,
    VAR_message TEXT,
    OUT VAR_res BOOLEAN
) 
SET client_min_messages = error
AS $$
BEGIN
    IF VAR_expected != VAR_received THEN 
        RAISE EXCEPTION '% - (expected %, got %)', VAR_message, VAR_expected, VAR_received; 
    END IF;
    VAR_res = true;
END; $$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fetchq_test.expect_equalStr(
    VAR_received CHARACTER VARYING,
    VAR_expected CHARACTER VARYING,
    VAR_message TEXT,
    OUT VAR_res BOOLEAN
) 
SET client_min_messages = error
AS $$
BEGIN
    IF VAR_expected != VAR_received THEN 
        RAISE EXCEPTION '% - (expected %, got %)', VAR_message, VAR_expected, VAR_received; 
    END IF;
    VAR_res = true;
END; $$
LANGUAGE plpgsql;
