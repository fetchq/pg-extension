
--
-- important regression tests
--
DROP FUNCTION IF EXISTS fetchq_test__queue_create_02();
DROP FUNCTION IF EXISTS fetchq_test__queue_drop_01();
DROP FUNCTION IF EXISTS fetchq_test__doc_push_03();
DROP FUNCTION IF EXISTS fetchq_test__doc_append_02();
DROP FUNCTION IF EXISTS fetchq_test__doc_upsert_01();
DROP FUNCTION IF EXISTS fetchq_test__doc_upsert_02();
DROP FUNCTION IF EXISTS fetchq_test__doc_pick_02();
DROP FUNCTION IF EXISTS fetchq_test__doc_reschedule_01();
DROP FUNCTION IF EXISTS fetchq_test__doc_reject_01();
DROP FUNCTION IF EXISTS fetchq_test__doc_complete_01();
DROP FUNCTION IF EXISTS fetchq_test__doc_kill_01();
DROP FUNCTION IF EXISTS fetchq_test__doc_drop_01();

DROP FUNCTION IF EXISTS fetchq_test__mnt_make_pending_01();
DROP FUNCTION IF EXISTS fetchq_test__mnt_reschedule_orphans_01();
DROP FUNCTION IF EXISTS fetchq_test__mnt_mark_dead_01();
DROP FUNCTION IF EXISTS fetchq_test__mnt_job_reschedule_01();
DROP FUNCTION IF EXISTS fetchq_test__mnt_job_run_01();
DROP FUNCTION IF EXISTS fetchq_test__mnt_01();

DROP FUNCTION IF EXISTS fetchq_test__metric_snap_01();
DROP FUNCTION IF EXISTS fetchq_test__metric_snap_02();
DROP FUNCTION IF EXISTS fetchq_test__metric_snap_03();
DROP FUNCTION IF EXISTS fetchq_test__metric_log_pack_01();




--
-- optional test
--
DROP FUNCTION IF EXISTS fetchq_test__queue_drop_02();
DROP FUNCTION IF EXISTS fetchq_test__queue_set_max_attempts_01();
DROP FUNCTION IF EXISTS fetchq_test__queue_drop_version_01();
DROP FUNCTION IF EXISTS fetchq_test__queue_drop_version_02();
DROP FUNCTION IF EXISTS fetchq_test__queue_drop_errors_01();
DROP FUNCTION IF EXISTS fetchq_test__queue_drop_errors_02();
DROP FUNCTION IF EXISTS fetchq_test__queue_drop_errors_03();
DROP FUNCTION IF EXISTS fetchq_test__queue_drop_metrics_01();
DROP FUNCTION IF EXISTS fetchq_test__queue_drop_metrics_02();

DROP FUNCTION IF EXISTS fetchq_test__doc_pick_03();
DROP FUNCTION IF EXISTS fetchq_test__doc_pick_04();
DROP FUNCTION IF EXISTS fetchq_test__doc_pick_05();
DROP FUNCTION IF EXISTS fetchq_test__doc_reschedule_02();
DROP FUNCTION IF EXISTS fetchq_test__doc_reject_02();
DROP FUNCTION IF EXISTS fetchq_test__doc_reject_03();
DROP FUNCTION IF EXISTS fetchq_test__doc_complete_02();

DROP FUNCTION IF EXISTS fetchq_test__mnt_reschedule_orphans_02();
DROP FUNCTION IF EXISTS fetchq_test__mnt_mark_dead_02();

DROP FUNCTION IF EXISTS fetchq_test__metric_get_02();
DROP FUNCTION IF EXISTS fetchq_test__metric_get_03();
DROP FUNCTION IF EXISTS fetchq_test__metric_get_total_01();
DROP FUNCTION IF EXISTS fetchq_test__metric_get_common_01();
DROP FUNCTION IF EXISTS fetchq_test__metric_get_all_01();
DROP FUNCTION IF EXISTS fetchq_test__metric_compute_01();
DROP FUNCTION IF EXISTS fetchq_test__metric_compute_all_01();
DROP FUNCTION IF EXISTS fetchq_test__metric_reset_01();
DROP FUNCTION IF EXISTS fetchq_test__metric_reset_all_01();
DROP FUNCTION IF EXISTS fetchq_test__doc_kill_02();

DROP FUNCTION IF EXISTS fetchq_test__log_error_01();
DROP FUNCTION IF EXISTS fetchq_test__log_error_02();
DROP FUNCTION IF EXISTS fetchq_test__utils_ts_retain_01();






--
-- duplicate test
-- 

DROP FUNCTION IF EXISTS fetchq_test__init();
DROP FUNCTION IF EXISTS fetchq_test__queue_create_01();
DROP FUNCTION IF EXISTS fetchq_test__doc_push_01();
DROP FUNCTION IF EXISTS fetchq_test__doc_push_02();
DROP FUNCTION IF EXISTS fetchq_test__doc_append_01();
DROP FUNCTION IF EXISTS fetchq_test__queue_set_current_version_01();
DROP FUNCTION IF EXISTS fetchq_test__metric_get_01();
DROP FUNCTION IF EXISTS fetchq_test__queue_create_03();
DROP FUNCTION IF EXISTS fetchq_test__doc_pick_01();
DROP FUNCTION IF EXISTS fetchq_test__mnt_run_01();
DROP FUNCTION IF EXISTS fetchq_test__mnt_run_all_01();
DROP FUNCTION IF EXISTS fetchq_test__mnt_job_pick_01();



--
-- load tests
--
DROP FUNCTION IF EXISTS fetchq_test__load_01();
DROP FUNCTION IF EXISTS fetchq_test__load_02();
DROP FUNCTION IF EXISTS fetchq_test__load_03();


--
-- DESTROY SCHEMA
--
DROP EXTENSION IF EXISTS fetchq;
DROP EXTENSION IF EXISTS "uuid-ossp";
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;

