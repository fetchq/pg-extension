version ?= 0.0.1
pg_version ?= 9.6

reset:
	rm -rf $(CURDIR)/data
	mkdir $(CURDIR)/data
	mkdir $(CURDIR)/data/pg

build-extension:
	cat $(CURDIR)/src/tables.sql \
		> $(CURDIR)/extension/fetchq--${version}.sql

build-test:
	mkdir -p $(CURDIR)/data
	cat $(CURDIR)/tests/create-extension.sql \
		> $(CURDIR)/data/fetchq-tests--${version}.sql

start-test: reset build-extension build-test
	docker run --rm -d \
		--name fetchq \
		-p 5432:5432 \
		-e "POSTGRES_USER=fetchq" \
		-e "POSTGRES_PASSWORD=fetchq" \
		-e "POSTGRES_DB=fetchq" \
		-v $(CURDIR)/data/pg:/var/lib/postgresql/data \
		-v $(CURDIR)/extension/fetchq.control:/usr/share/postgresql/$(pg_version)/extension/fetchq.control \
		-v $(CURDIR)/extension/fetchq--${version}.sql:/usr/share/postgresql/$(pg_version)/extension/fetchq--${version}.sql \
		-v $(CURDIR)/data/fetchq-tests--${version}.sql:/tests/fetchq-tests--${version}.sql \
		postgres:$(pg_version)

start-test-delay:
	sleep 20

stop-test:
	docker stop fetchq

test-run: build-test
	docker exec \
		fetchq \
		psql \
			-h localhost \
			--username fetchq \
			--dbname fetchq \
			-a -f /tests/fetchq-tests--${version}.sql

test: start-test start-test-delay test-run stop-test
