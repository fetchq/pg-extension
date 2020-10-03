
registry ?= fetchq
name ?= fetchq
version ?= 3.1.0

## Testing with Postgres Versions
## It's a good idea to always test with all the versions
## it's manual and it sucks, we'll see about that in the future

# 9.6 10.11 11.6 12.1 12.4 13.0
pg_version ?= 13.0
# 9.6 10 11.6 12 13
pg_extension_folder ?= 13

reset:
	# Cleanup current db
	docker stop fetchq || true
	docker rm -f fetchq || true

	# Cleanup data folders
	rm -rf $(CURDIR)/data
	rm -rf $(CURDIR)/extension
	mkdir $(CURDIR)/data
	mkdir $(CURDIR)/data/pg
	mkdir $(CURDIR)/extension

build:
	mkdir -p $(CURDIR)/extension
	cp $(CURDIR)/src/fetchq.control $(CURDIR)/extension/fetchq.control
	cat $(CURDIR)/src/info.sql \
		$(CURDIR)/src/trigger-notify-as-json.sql \
		$(CURDIR)/src/init.sql \
		$(CURDIR)/src/destroy.sql \
		$(CURDIR)/src/metric-set.sql \
		$(CURDIR)/src/metric-increment.sql \
		$(CURDIR)/src/metric-log-set.sql \
		$(CURDIR)/src/metric-log-increment.sql \
		$(CURDIR)/src/metric-log-decrement.sql \
		$(CURDIR)/src/metric-log-pack.sql \
		$(CURDIR)/src/metric-get.sql \
		$(CURDIR)/src/metric-get-total.sql \
		$(CURDIR)/src/metric-get-common.sql \
		$(CURDIR)/src/metric-get-all.sql \
		$(CURDIR)/src/metric-compute.sql \
		$(CURDIR)/src/metric-compute-all.sql \
		$(CURDIR)/src/metric-reset.sql \
		$(CURDIR)/src/metric-reset-all.sql \
		$(CURDIR)/src/metric-snap.sql \
		$(CURDIR)/src/doc-push.sql \
		$(CURDIR)/src/doc-push-many.sql \
		$(CURDIR)/src/doc-append.sql \
		$(CURDIR)/src/doc-upsert.sql \
		$(CURDIR)/src/doc-pick.sql \
		$(CURDIR)/src/doc-reschedule.sql \
		$(CURDIR)/src/doc-reject.sql \
		$(CURDIR)/src/doc-complete.sql \
		$(CURDIR)/src/doc-kill.sql \
		$(CURDIR)/src/doc-drop.sql \
		$(CURDIR)/src/mnt-make-pending.sql \
		$(CURDIR)/src/mnt-reschedule-orphans.sql \
		$(CURDIR)/src/mnt-mark-dead.sql \
		$(CURDIR)/src/mnt-run.sql \
		$(CURDIR)/src/mnt-job-pick.sql \
		$(CURDIR)/src/mnt-job-reschedule.sql \
		$(CURDIR)/src/mnt-job-run.sql \
		$(CURDIR)/src/mnt.sql \
		$(CURDIR)/src/log-error.sql \
		$(CURDIR)/src/queue-get-id.sql \
		$(CURDIR)/src/queue-triggers.sql \
		$(CURDIR)/src/queue-create.sql \
		$(CURDIR)/src/queue-create-indexes.sql \
		$(CURDIR)/src/queue-drop.sql \
		$(CURDIR)/src/queue-set-max-attempts.sql \
		$(CURDIR)/src/queue-set-current-version.sql \
		$(CURDIR)/src/queue-set-logs-retention.sql \
		$(CURDIR)/src/queue-set-metrics-retention.sql \
		$(CURDIR)/src/queue-drop-version.sql \
		$(CURDIR)/src/queue-drop-logs.sql \
		$(CURDIR)/src/queue-drop-metrics.sql \
		$(CURDIR)/src/queue-drop-indexes.sql \
		$(CURDIR)/src/queue-top.sql \
		$(CURDIR)/src/queue-status.sql \
		$(CURDIR)/src/queue-truncate.sql \
		$(CURDIR)/src/utils-ts-retain.sql \
		$(CURDIR)/src/trace.sql \
		> $(CURDIR)/extension/fetchq--${version}.sql

build-test:
	mkdir -p $(CURDIR)/data
	cat $(CURDIR)/tests/_before.sql \
		$(CURDIR)/tests/init.test.sql \
		$(CURDIR)/tests/queue-create.test.sql \
		$(CURDIR)/tests/queue-create-indexes.test.sql \
		$(CURDIR)/tests/queue-drop.test.sql \
		$(CURDIR)/tests/queue-top.test.sql \
		$(CURDIR)/tests/queue-status.test.sql \
		$(CURDIR)/tests/queue-triggers.test.sql \
		$(CURDIR)/tests/doc-push.test.sql \
		$(CURDIR)/tests/doc-append.test.sql \
		$(CURDIR)/tests/doc-upsert.test.sql \
		$(CURDIR)/tests/doc-pick.test.sql \
		$(CURDIR)/tests/doc-reschedule.test.sql \
		$(CURDIR)/tests/doc-reject.test.sql \
		$(CURDIR)/tests/doc-complete.test.sql \
		$(CURDIR)/tests/doc-kill.test.sql \
		$(CURDIR)/tests/doc-drop.test.sql \
		$(CURDIR)/tests/mnt-make-pending.test.sql \
		$(CURDIR)/tests/mnt-reschedule-orphans.test.sql \
		$(CURDIR)/tests/mnt-mark-dead.test.sql \
		$(CURDIR)/tests/mnt-run.test.sql \
		$(CURDIR)/tests/mnt-job-pick.test.sql \
		$(CURDIR)/tests/mnt-job-reschedule.test.sql \
		$(CURDIR)/tests/mnt-job-run.test.sql \
		$(CURDIR)/tests/mnt.test.sql \
		$(CURDIR)/tests/metric-get.test.sql \
		$(CURDIR)/tests/metric-get-total.test.sql \
		$(CURDIR)/tests/metric-get-common.test.sql \
		$(CURDIR)/tests/metric-get-all.test.sql \
		$(CURDIR)/tests/metric-compute.test.sql \
		$(CURDIR)/tests/metric-compute-all.test.sql \
		$(CURDIR)/tests/metric-reset.test.sql \
		$(CURDIR)/tests/metric-reset-all.test.sql \
		$(CURDIR)/tests/metric-snap.test.sql \
		$(CURDIR)/tests/metric-log-pack.test.sql \
		$(CURDIR)/tests/log-error.test.sql \
		$(CURDIR)/tests/queue-set-max-attempts.test.sql \
		$(CURDIR)/tests/queue-set-current-version.test.sql \
		$(CURDIR)/tests/queue-drop-version.test.sql \
		$(CURDIR)/tests/queue-drop-errors.test.sql \
		$(CURDIR)/tests/queue-drop-metrics.test.sql \
		$(CURDIR)/tests/queue-drop-indexes.test.sql \
		$(CURDIR)/tests/queue-status.test.sql \
		$(CURDIR)/tests/queue-truncate.test.sql \
		$(CURDIR)/tests/utils-ts-retain.test.sql \
		$(CURDIR)/tests/trace.test.sql \
		$(CURDIR)/tests/load.test.sql \
		$(CURDIR)/tests/_run.sql \
		$(CURDIR)/tests/_after.sql \
		> $(CURDIR)/data/fetchq--${version}.test.sql

build-image: reset build
	docker build --no-cache -t ${name}:9.6-${version} -f Dockerfile-9.6 .
	docker build --no-cache -t ${name}:10.4-${version} -f Dockerfile-10.4 .
	docker build --no-cache -t ${name}:10.11-${version} -f Dockerfile-10.11 .
	docker build --no-cache -t ${name}:11.6-${version} -f Dockerfile-11.6 .
	docker build --no-cache -t ${name}:12.0-${version} -f Dockerfile-12.0 .
	docker build --no-cache -t ${name}:12.1-${version} -f Dockerfile-12.1 .
	docker build --no-cache -t ${name}:12.4-${version} -f Dockerfile-12.4 .
	docker build --no-cache -t ${name}:13.0-${version} -f Dockerfile-13.0 .

publish: build-image
	# 9.6
	docker tag ${name}:9.6-${version} ${registry}/${name}:9.6-${version}
	docker tag ${name}:9.6-${version} ${registry}/${name}:9.6-latest
	docker push ${registry}/${name}:9.6-${version}
	docker push ${registry}/${name}:9.6-latest
	# 10.4
	docker tag ${name}:10.4-${version} ${registry}/${name}:10.4-${version}
	docker tag ${name}:10.4-${version} ${registry}/${name}:10.4-latest
	docker push ${registry}/${name}:10.4-${version}
	docker push ${registry}/${name}:10.4-latest
	# 10.11
	docker tag ${name}:10.11-${version} ${registry}/${name}:10.11-${version}
	docker tag ${name}:10.11-${version} ${registry}/${name}:10.11-latest
	docker push ${registry}/${name}:10.11-${version}
	docker push ${registry}/${name}:10.11-latest
	# 11.6
	docker tag ${name}:11.6-${version} ${registry}/${name}:11.6-${version}
	docker tag ${name}:11.6-${version} ${registry}/${name}:11.6-latest
	docker push ${registry}/${name}:11.6-${version}
	docker push ${registry}/${name}:11.6-latest
	# 12.0
	docker tag ${name}:12.0-${version} ${registry}/${name}:12.0-${version}
	docker tag ${name}:12.0-${version} ${registry}/${name}:12.0-latest
	docker push ${registry}/${name}:12.0-${version}
	docker push ${registry}/${name}:12.0-latest
	# 12.1
	docker tag ${name}:12.1-${version} ${registry}/${name}:12.1-${version}
	docker tag ${name}:12.1-${version} ${registry}/${name}:12.1-latest
	docker push ${registry}/${name}:12.1-${version}
	docker push ${registry}/${name}:12.1-latest
	# 12.4
	docker tag ${name}:12.4-${version} ${registry}/${name}:12.4-${version}
	docker tag ${name}:12.4-${version} ${registry}/${name}:12.4-latest
	docker push ${registry}/${name}:12.4-${version}
	docker push ${registry}/${name}:12.4-latest
	# 13.0
	docker tag ${name}:13.0-${version} ${registry}/${name}:13.0-${version}
	docker tag ${name}:13.0-${version} ${registry}/${name}:13.0-latest
	docker push ${registry}/${name}:13.0-${version}
	docker push ${registry}/${name}:13.0-latest
	# latest
	docker tag ${name}:13.0-${version} ${registry}/${name}:latest
	docker push ${registry}/${name}:latest

start-pg:
	docker run --rm -d \
		--name fetchq \
		-p 5432:5432 \
		-e POSTGRES_PASSWORD=postgres \
		-v $(CURDIR)/data/pg:/var/lib/postgresql/data \
		-v $(CURDIR)/extension/fetchq.control:/usr/share/postgresql/$(pg_extension_folder)/extension/fetchq.control \
		-v $(CURDIR)/extension/fetchq--${version}.sql:/usr/share/postgresql/$(pg_extension_folder)/extension/fetchq--${version}.sql \
		-v $(CURDIR)/data/fetchq--${version}.test.sql:/tests/fetchq--${version}.test.sql \
		postgres:$(pg_version)

production: reset build-image
	docker run --rm -d \
		-e POSTGRES_PASSWORD=postgres \
		--name fetchq \
		-p 5432:5432 \
		fetchq:$(pg_version)-$(version)
	docker logs -f fetchq

start-delay:
	until docker exec fetchq pg_isready ; do sleep 1 ; done
	sleep 2

start: reset build build-test start-pg
	docker logs -f fetchq

stop:
	docker stop fetchq

test: reset build build-test start-pg start-delay test-run stop

test-run: build build-test
	docker exec \
		fetchq \
		psql \
			-v ON_ERROR_STOP=1 \
			-h localhost \
			--username postgres \
			--dbname postgres \
			-a -f /tests/fetchq--${version}.test.sql

init: build
	docker exec \
		fetchq \
		psql \
			-v ON_ERROR_STOP=1 \
			-h localhost \
			--username postgres \
			--dbname postgres \
			-c 'DROP SCHEMA public CASCADE;CREATE SCHEMA public;CREATE EXTENSION fetchq;SELECT * FROM fetchq_init();'
