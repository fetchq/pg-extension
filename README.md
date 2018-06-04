# fetchq-pg-extension
Postgres extension that enables FetchQ capabilities

## Queue Tables

fq__${queueName}__data
fq__${queueName}__errors
fq__${queueName}__metrics

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

## Management Tables

fq_sys_queues
fq_sys_metrics
fq_sys_metrics_writes
fq_sys_tasks
fq_sys_tasks_errors