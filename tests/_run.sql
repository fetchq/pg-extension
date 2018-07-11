
--
-- important regression tests
--
SELECT * FROM fetchq_test__queue_create_02();
SELECT * FROM fetchq_test__queue_drop_01();
SELECT * FROM fetchq_test__doc_push_03();
SELECT * FROM fetchq_test__doc_append_02();
SELECT * FROM fetchq_test__doc_upsert_01();
SELECT * FROM fetchq_test__doc_upsert_02();
SELECT * FROM fetchq_test__doc_pick_02();
SELECT * FROM fetchq_test__doc_reschedule_01();
SELECT * FROM fetchq_test__doc_reject_01();
SELECT * FROM fetchq_test__doc_complete_01();
SELECT * FROM fetchq_test__doc_kill_01();
SELECT * FROM fetchq_test__doc_drop_01();

SELECT * FROM fetchq_test__mnt_make_pending_01();
SELECT * FROM fetchq_test__mnt_reschedule_orphans_01();
SELECT * FROM fetchq_test__mnt_mark_dead_01();
SELECT * FROM fetchq_test__mnt_job_reschedule_01();
SELECT * FROM fetchq_test__mnt_job_run_01();

SELECT * FROM fetchq_test__metric_snap_01();
SELECT * FROM fetchq_test__metric_snap_02();
SELECT * FROM fetchq_test__metric_snap_03();
SELECT * FROM fetchq_test__metric_log_pack_01();




--
-- optional test
--
-- SELECT * FROM fetchq_test__queue_drop_02();
-- SELECT * FROM fetchq_test__queue_set_max_attempts_01();
-- SELECT * FROM fetchq_test__queue_drop_version_01();
-- SELECT * FROM fetchq_test__queue_drop_version_02();
-- SELECT * FROM fetchq_test__queue_drop_errors_01();
-- SELECT * FROM fetchq_test__queue_drop_errors_02();
-- SELECT * FROM fetchq_test__queue_drop_errors_03();
-- SELECT * FROM fetchq_test__queue_drop_metrics_01();
-- SELECT * FROM fetchq_test__queue_drop_metrics_02();

-- SELECT * FROM fetchq_test__doc_pick_03();
-- SELECT * FROM fetchq_test__doc_pick_04();
-- SELECT * FROM fetchq_test__doc_pick_05();
-- SELECT * FROM fetchq_test__doc_reschedule_02();
-- SELECT * FROM fetchq_test__doc_reject_02();
-- SELECT * FROM fetchq_test__doc_reject_03();
-- SELECT * FROM fetchq_test__doc_complete_02();

-- SELECT * FROM fetchq_test__mnt_reschedule_orphans_02();
-- SELECT * FROM fetchq_test__mnt_mark_dead_02();

-- SELECT * FROM fetchq_test__metric_get_02();
-- SELECT * FROM fetchq_test__metric_get_03();
-- SELECT * FROM fetchq_test__metric_get_total_01();
-- SELECT * FROM fetchq_test__metric_get_common_01();
-- SELECT * FROM fetchq_test__metric_get_all_01();
-- SELECT * FROM fetchq_test__metric_compute_01();
-- SELECT * FROM fetchq_test__metric_compute_all_01();
-- SELECT * FROM fetchq_test__metric_reset_01();
-- SELECT * FROM fetchq_test__metric_reset_all_01();
-- SELECT * FROM fetchq_test__doc_kill_02();

-- SELECT * FROM fetchq_test__log_error_01();
-- SELECT * FROM fetchq_test__log_error_02();
-- SELECT * FROM fetchq_test__utils_ts_retain_01();






--
-- duplicate test
-- 

-- SELECT * FROM fetchq_test__init();
-- SELECT * FROM fetchq_test__queue_create_01();
-- SELECT * FROM fetchq_test__doc_push_01();
-- SELECT * FROM fetchq_test__doc_push_02();
-- SELECT * FROM fetchq_test__doc_append_01();
-- SELECT * FROM fetchq_test__queue_set_current_version_01();
-- SELECT * FROM fetchq_test__metric_get_01();
-- SELECT * FROM fetchq_test__queue_create_03();
-- SELECT * FROM fetchq_test__doc_pick_01();
-- SELECT * FROM fetchq_test__mnt_run_01();
-- SELECT * FROM fetchq_test__mnt_run_all_01();
-- SELECT * FROM fetchq_test__mnt_job_pick_01();




-- load tests
-- SELECT * FROM fetchq_test__load_01(10000);
-- SELECT * FROM fetchq_test__load_02(5000);
-- SELECT * FROM fetchq_test__load_03(10, 10000);