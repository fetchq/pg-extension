# Fetchq Postgres Extension

Postgres extension that enables FetchQ capabilities.

- [Quick Start](#quick-start)
- [Queue Basics](#queue-basics)
- [FIFO Workflow](#fifo-workflow)
- [Planned Workflow](#planned-workflow)
- [Consuming a Queue](#consuming-a-queue)
- [Handling a Document](#handling-a-document)
- [Data Structure](#data-structure)
- [Quick Start (local)](#quick-start-local)
- [Development](#development)

---

## Quick Start

Fetchq is distributed as a Docker image, you can download from:
https://hub.docker.com/r/fetchq/fetchq

You can run it from any Docker-enabled machine with the following command:

```bash
docker run --rm \
	--name fetchq \
	-p 5432:5432 \
	-e "POSTGRES_PASSWORD=postgres" \
	fetchq/fetchq:13.0-3.0.0
```

This runs a PostgreSQL instance with Fetchq installed and ready to work.

## Queue Basics

The first step in using Fetchq is to assert a queue:

```sql
SELECT * FROM fetchq.queue_create('q1');
```

This command will return a `queue_id` and a `was_created` flag that tells you whether the queue did exists or not.

Once you are done with the queue and want to drop it, you can run the following command:

```sql
SELECT * FROM fetchq.queue_drop('q1');
```
---

## FIFO Workflow

First-in-first-out is a classic queue paradigm where a document is **appendend** at the end of the queue, and the queue is processed from the top.

In Fetchq a document is a simple JSON and you can append it using the following command:

```sql
SELECT * FROM fetchq.doc_append('q1', '{"foo": 123}', 0, 0);
```

The signature of the function is:

```
fetchq.doc_append(
  queueName,
  document,
  version,
  priority
): subject
```

> **NOTE:** more about version and priority later.

With this method you and append the same document multiple times, if you need to insert unique documents please refer to the next paragraph.

## Planned Workflow

The following method inserts a document in the queue at an arbitrary point that is decided by the **expected execution date**:

```sql
SELECT * FROM fetchq.doc_push('q1', 'doc1', 0, 0, NOW() + INTERVAL '1m', '{"foo": 123}');
```

The signature of the function is:

```
fetchq.doc_push(
  queueName,
  subject,
  version,
  priority,
  nextIteration,
  document
): queued_docs
```

--

### The Document's Subject

When you insert a document using the `doc_push` method you are in control of its subject. That is a string and it is unique in the queue.

If you try to push the same subject twice, the second request will silently fail and you get a `queued_docs=0` response.

### The nextIteration

The `nextIteration` is a point in time before which it is guaranteed that the document will NOT be executed.

As any queue systems, documents get processed by some workers. So Fetchq will make the document visible for processing only when `nextIteration` is in the past.

👉 A classic trick that I use when I want to run a document righ away in a planned queue is to set this parameter some hundred centuries in the past.

### Version

The version parameter is an integer that should refer to the document's payload schema.

When you ask Fetchq for a document to process, you can specify the version you are interesed into.

👉 This makes it possible to progressively migrate document's payload schemas through time.

### Priority

The priority is an integer that is used to choose which document to iterate first. 

> The higher the priority, the earlier the processing.

The priority is independend from the `nextIteration`. Among all the documents due for execution, documents with the higher priority get processed first.

---

## Consuming a Queue

The reason behind the "fetch" in "Fetchq" is that basic clients implement a simple polling mechanism to ask:  
**_what do I do now?_**

> A lot of efforts were made to make this question
> easy to answer from the db point of view. 
> [Partial indexes](https://www.postgresql.org/docs/current/indexes-partial.html) were the key to success.



```sql
SELECT * FROM fetchq.doc_pick('q1', 0, 1, '5s');
```

The signature of the function is:

```
fetchq.doc_pick(
  queueName,
  version,
  limit,
  lockDuration
): documentRow
```

### version

[[ TO BE COMPLETED ]]

### limit

[[ TO BE COMPLETED ]]

### lockDuration

[[ TO BE COMPLETED ]]

---

## Handling a Document

Once you are done processin the document, you should communicate back to Fetchq what do you plan to do with it. 

Here are the options:

### Drop

[[ TO BE COMPLETED ]]

```sql
SELECT * FROM fetchq.doc_drop('q1', 'doc1');
```

### Complete

[[ TO BE COMPLETED ]]

```sql
SELECT * FROM fetchq.doc_complete('q1', 'doc1');
```

### Reschedule

[[ TO BE COMPLETED ]]

```sql
SELECT * FROM fetchq.doc_reschedule('q1', 'doc1', NOW() + INTERVAL '1d');
```

### Kill

[[ TO BE COMPLETED ]]

```sql
SELECT * FROM fetchq.doc_kill('q1', 'doc1');
```

### Reject

[[ TO BE COMPLETED ]]



---

## The Maintenance Job

```sql
SELECT * FROM fetchq.mnt_run_all(100);
```

---

## Data Structure

[[ TO BE COMPLETED ]]

## Quick Start (local)

You can easily run the production version of Fetchq using Docker on a Linux machine:

```bash
make production
```

At this point you can connect to:

```
postgres://postgres:${POSTGRES_PASSWORD:-postgres}@postgres:5432/postgres
```

This will give you an empty PostgreSQL instance with Fetchq installed as an extension and initialized as well.

From here, you can just start creating queues and handling documents:

```sql
select * from fetchq.queue_create('foo');
select * from fetchq.doc_append('foo', '{"a":1}', 0, 0);
```

## Development

- `make start` will run postgres
- `make stop` will kill postgres
- `make test-run` will build the extension and run the tests
  against a running Postgres instance
- `make test` runs a full test agains a newly created database instance
- `make init` re-initialize a running Postgres instance