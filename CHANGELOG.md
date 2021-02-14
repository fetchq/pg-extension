# FetchQ Changelog

## v3.2.0

- Uses `uuid` data type in `fetchq.metrics_writes` to prevent
  running out of integer IDs over time.  
  (https://github.com/fetchq/pg-extension/issues/38)
- Reduces `metric_writes` by ignoring increments of Zero value
- Add new methods:
  - `fetchq.doc_push('queue', 'subject')`
  - `fetchq.doc_push('queue', 'subject', '{"payload": true}')`
  - `fetchq.doc_push('queue', 'subject', '{"payload": true}', NOW() + INTERVAL '5m')`
  - `fetchq.doc_append('queue', '{"payload": true}')`

### Migrating from a previous version:

> **NOTE:** we suggest you stop all your workers and put your 
> Fetchq on hold while performing the upgrade operation. 
> 
> If anything goes wrong, this should only screw up the counters
> and you can easily rebuild them.
>
> It should be a safe operation 😇.

Migrating from version 3.1.0 is quite easy as we started to
provide migration scripts as built-in functions:

```sql
SELECT * FROM fetchq.upgrade__310__311();
```

From previous versions, you may need to adjust the following SQL:

```sql
BEGIN;
-- temporary cast integers to strings:
ALTER TABLE "fetchq"."metrics_writes" 
ALTER COLUMN "id" SET DATA TYPE VARCHAR(36),
ALTER COLUMN "id" SET DEFAULT uuid_generate_v1();

-- update the existing lines to use uuids:
UPDATE "fetchq"."metrics_writes" SET "id" = uuid_generate_v1();

-- cast the string type to be uuid:
ALTER TABLE "fetchq"."metrics_writes"
ALTER COLUMN "id" SET DATA TYPE UUID USING "id"::UUID,
ALTER COLUMN "id" SET DEFAULT uuid_generate_v1();

-- drop the integer sequence:
DROP SEQUENCE IF EXISTS "fetchq"."metrics_writes_id_seq" CASCADE;
COMMIT;
```



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
