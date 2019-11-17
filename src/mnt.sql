DROP FUNCTION IF EXISTS fetchq_mnt(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_mnt (
    PAR_lockDuration VARCHAR,
	OUT processed INTEGER,
	OUT packed INTEGER
) AS $$
DECLARE
    VAR_countJobs INTEGER;
    VAR_r RECORD;
BEGIN
    -- set all the jobs to be executed
    -- (skip generic jobs)
    UPDATE fetchq_catalog.fetchq_sys_jobs SET next_iteration = NOW() - INTERVAL '1ms'
    WHERE queue != '*';

    -- run all the available jobs
    GET DIAGNOSTICS VAR_countJobs := ROW_COUNT;
    SELECT * INTO VAR_r FROM fetchq_mnt_job_run(PAR_lockDuration, VAR_countJobs);
	processed = VAR_r.processed;

    -- pack the generated metrics
    SELECT affected_rows INTO packed FROM fetchq_metric_log_pack();
    -- RAISE NOTICE 'packed = %', packed;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fetchq_mnt();
CREATE OR REPLACE FUNCTION fetchq_mnt (
	OUT processed INTEGER,
	OUT packed INTEGER
) AS $$
DECLARE
    VAR_r RECORD;
BEGIN
    SELECT * INTO VAR_r FROM fetchq_mnt('5m');
    processed = VAR_r.processed;
    packed = VAR_r.packed;
END; $$
LANGUAGE plpgsql;