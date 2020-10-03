# FetchQ - queue_truncate(name, [extended])

It drops all the documents from a queue and resets the metrics:

```sql
PERFORM fetchq.queue_truncate('foo');
```

You can pass an optional parameter `true` to also remove logs, metrics and reset the counters of
any related maintenance job:

```sql
PERFORM fetchq.queue_truncate('foo', true);
```

You can also use the extended version `_all` that apply the truncate to every queue in the database:

```sql
-- drop all documents
PERFORM fetchq.queue_truncate_all();

-- drop all documents, metrics, logs, reset maintenance jobs
PERFORM fetchq.queue_truncate_all(true);
```
