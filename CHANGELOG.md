# FetchQ Changelog

## v3.1.0

- Adds `fetchq.queue_truncate('queue_name')` to drop current documents in a queue
- Adds `fetchq.queue_truncate('queue_name', true)` to completely void a queue
- Adds `fetchq.queue_truncate_all()` to drop all the documents in the existing queues
- Adds `fetchq.queue_truncate_all(true)` to remove all data from the system

## v2.2.0

- Adds `fetchq_trace(subject)` api.
- Improves migration instructions 1.x -> 2.x

## v2.1.1

- Fixes bug #26 which prevented `fetchq_metric_compute_all()` to work.

## v2.1.0

- Adds `fetchq_queue_create_indexes(qname)` signature that generate per-queue indexes
  based on informations read from the `sys_queues` table.
- Adds `fetchq_trigger_notify_as_json()` that can be attached to any table to emit a full
  JSON representation of the event (INSERT; UPDATE; DELETE).
- Emits full JSON events for `fetchq_sys_queues` so that the client can subscribe to it and
  honor the queue status.

## v2.0.0

- Introduces the `fetchq_catalog` schema where to collect all the FetchQ related tables
