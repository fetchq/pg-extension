# FetchQ Postgres Extension

Postgres extension that enables FetchQ capabilities

## How to Work this out

- `make start` will run postgres
- `make stop` will kill postgres
- `make test-run` will build the extension and run the tests
  against a running Postgres instance
- `make test` runs a full test agains a newly created database instance
- `make init` re-initialize a running Postgres instance

---

## Management Tables

fetchq_sys_queues
fetchq_sys_metrics
fetchq_sys_metrics_writes
fetchq_sys_tasks
fetchq_sys_tasks_errors


## Queue Tables

fetchq__${queueName}__documents
fetchq__${queueName}__errors
fetchq__${queueName}__metrics

## Queue Metrics

#### current counts
cnt - current count
pnd - current pending count
pln - current planned count
act - current active count
cpl - current completed count
kll - current completed kill

#### general metrics

ent - documents that have entered the queue
drp - documents that have been dropped
pkd - documents that have been piked
prc - documents that have been processed (either of the possible actions)

#### status metrics

res - documents that have been rescheduled
rej - documents that have been rejected
orp - documents that have been rescheduled because they were orphans
err - (= rej + orp)

## Run from Docker Hub

https://hub.docker.com/r/fetchq/fetchq/tags/

```
docker run --rm -d \
		--name fetchq \
		-p 5432:5432 \
		-e "POSTGRES_USER=fetchq" \
		-e "POSTGRES_PASSWORD=fetchq" \
		-e "POSTGRES_DB=fetchq" \
		fetchq/fetchq:10.4
```