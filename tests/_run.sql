
CREATE OR REPLACE FUNCTION fetchq_test.__runWIP(
    OUT done BOOLEAN
) AS $$
DECLARE
    VAR_errMessage TEXT;
BEGIN
    BEGIN

        -- >>> Run tests
        PERFORM fetchq_test.__run('init', 'It should initialize Fetchq');
        -- <<<

    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS VAR_errMessage = MESSAGE_TEXT;
        RAISE EXCEPTION '%', VAR_errMessage;
    END;
    done = TRUE;
END; $$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fetchq_test.__runBasics(
    OUT done BOOLEAN
) AS $$
DECLARE
    VAR_errMessage TEXT;
BEGIN
    BEGIN

        -- >>> Run tests
        PERFORM fetchq_test.__run('init', 'It should initialize Fetchq');
        PERFORM fetchq_test.__run('queue_create_01', '');
        PERFORM fetchq_test.__run('queue_create_indexes_01', '');
        PERFORM fetchq_test.__run('queue_drop_01', '');
        PERFORM fetchq_test.__run('queue_top_01', '');
        PERFORM fetchq_test.__run('queue_triggers_01', '');
        PERFORM fetchq_test.__run('doc_push_01', '');
        PERFORM fetchq_test.__run('doc_append_01', '');
        PERFORM fetchq_test.__run('doc_upsert_01', '');
        PERFORM fetchq_test.__run('doc_pick_01', '');
        PERFORM fetchq_test.__run('doc_reschedule_01', '');
        PERFORM fetchq_test.__run('doc_reject_01', '');
        PERFORM fetchq_test.__run('doc_complete_01', '');
        PERFORM fetchq_test.__run('doc_kill_01', '');
        PERFORM fetchq_test.__run('doc_drop_01', '');
        -- <<<

    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS VAR_errMessage = MESSAGE_TEXT;
        RAISE EXCEPTION '%', VAR_errMessage;
    END;
    done = TRUE;
END; $$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fetchq_test.__runOptionals(
    OUT done BOOLEAN
) AS $$
DECLARE
    VAR_errMessage TEXT;
BEGIN
    BEGIN

        -- >>> Run tests
        PERFORM fetchq_test.__run('queue_create_02', '');
        PERFORM fetchq_test.__run('queue_create_03', '');
        PERFORM fetchq_test.__run('queue_status_01', '');
        PERFORM fetchq_test.__run('queue_drop_02', '');
        
        PERFORM fetchq_test.__run('doc_push_02', '');
        PERFORM fetchq_test.__run('doc_push_03', '');
        PERFORM fetchq_test.__run('doc_append_02', '');
        PERFORM fetchq_test.__run('doc_upsert_02', '');
        PERFORM fetchq_test.__run('doc_pick_02', '');
        PERFORM fetchq_test.__run('doc_pick_03', '');
        PERFORM fetchq_test.__run('doc_pick_04', '');
        PERFORM fetchq_test.__run('doc_pick_05', '');
        
        PERFORM fetchq_test.__run('doc_reschedule_02', '');
        
        PERFORM fetchq_test.__run('doc_reject_02', '');
        PERFORM fetchq_test.__run('doc_reject_03', '');
        
        PERFORM fetchq_test.__run('doc_complete_02', '');
        
        PERFORM fetchq_test.__run('doc_kill_02', '');
        

        PERFORM fetchq_test.__run('mnt_make_pending_01', '');
        PERFORM fetchq_test.__run('mnt_reschedule_orphans_01', '');
        PERFORM fetchq_test.__run('mnt_reschedule_orphans_02', '');
        PERFORM fetchq_test.__run('mnt_mark_dead_01', '');
        PERFORM fetchq_test.__run('mnt_mark_dead_02', '');
        PERFORM fetchq_test.__run('mnt_job_reschedule_01', '');
        PERFORM fetchq_test.__run('mnt_job_run_01', '');
        PERFORM fetchq_test.__run('mnt_01', '');

        PERFORM fetchq_test.__run('metric_snap_01', '');
        PERFORM fetchq_test.__run('metric_snap_02', '');
        PERFORM fetchq_test.__run('metric_snap_03', '');
        PERFORM fetchq_test.__run('metric_log_pack_01', '');

        PERFORM fetchq_test.__run('log_error_01', '');
        PERFORM fetchq_test.__run('log_error_02', '');

        PERFORM fetchq_test.__run('queue_set_max_attempts_01', '');
        PERFORM fetchq_test.__run('queue_set_current_version_01', '');
        PERFORM fetchq_test.__run('queue_drop_version_01', '');
        PERFORM fetchq_test.__run('queue_drop_version_02', '');
        PERFORM fetchq_test.__run('queue_drop_logs_01', '');
        PERFORM fetchq_test.__run('queue_drop_logs_02', '');
        PERFORM fetchq_test.__run('queue_drop_logs_03', '');
        PERFORM fetchq_test.__run('queue_drop_metrics_01', '');
        PERFORM fetchq_test.__run('queue_drop_metrics_02', '');
        PERFORM fetchq_test.__run('queue_drop_indexes_01', '');
        PERFORM fetchq_test.__run('queue_status_01', '');
        PERFORM fetchq_test.__run('utils_ts_retain_01', '');
        PERFORM fetchq_test.__run('trace_01', '');
        -- <<<

    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS VAR_errMessage = MESSAGE_TEXT;
        RAISE EXCEPTION '%', VAR_errMessage;
    END;
    done = TRUE;
END; $$
LANGUAGE plpgsql;



-- Define which groups to run
select * from fetchq_test.__runWIP();
select * from fetchq_test.__runBasics();
select * from fetchq_test.__runOptionals();



-- load tests
-- SELECT * FROM fetchq_test.load_01(10000);
-- SELECT * FROM fetchq_test.load_02(5000);
-- SELECT * FROM fetchq_test.load_03(10, 10000);