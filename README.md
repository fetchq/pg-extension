# fetchq-pg-extension
Postgres extension that enables FetchQ capabilities

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
prd - documents that have been processed (either of the possible actions)

#### status metrics

res - documents that have been rescheduled
rej - documents that have been rejected
err - documents that have been triggered an unexpected error

## How to Work this out

1. `make test-start` will run postgres
2. `make test-run` will build the extension and run the tests
3. `make test-stop` will kill postgres