version ?= 0.0.1
pg_version ?= 9.6

reset:
	rm -rf $(CURDIR)/data
	mkdir $(CURDIR)/data
	mkdir $(CURDIR)/data/pg

build-extension:
	cp $(CURDIR)/src/fetchq.control $(CURDIR)/extension/fetchq.control
	cat $(CURDIR)/src/sys-tables.sql \
		$(CURDIR)/src/get-queue-id.sql \
		$(CURDIR)/src/create-queue.sql \
		$(CURDIR)/src/drop-queue.sql \
		> $(CURDIR)/extension/fetchq--${version}.sql

build-test:
	mkdir -p $(CURDIR)/data
	cat $(CURDIR)/tests/sys-tables.test.sql \
		$(CURDIR)/tests/create-queue.test.sql \
		$(CURDIR)/tests/drop-queue.test.sql \
		> $(CURDIR)/data/fetchq--${version}.test.sql

test-start-pg: reset build-extension build-test
	docker run --rm -d \
		--name fetchq \
		-p 5432:5432 \
		-e "POSTGRES_USER=fetchq" \
		-e "POSTGRES_PASSWORD=fetchq" \
		-e "POSTGRES_DB=fetchq" \
		-v $(CURDIR)/data/pg:/var/lib/postgresql/data \
		-v $(CURDIR)/extension/fetchq.control:/usr/share/postgresql/$(pg_version)/extension/fetchq.control \
		-v $(CURDIR)/extension/fetchq--${version}.sql:/usr/share/postgresql/$(pg_version)/extension/fetchq--${version}.sql \
		-v $(CURDIR)/data/fetchq--${version}.test.sql:/tests/fetchq--${version}.test.sql \
		postgres:$(pg_version)

test-start-delay:
	sleep 20

test-start: test-start-pg
	docker logs -f fetchq

test-stop:
	docker stop fetchq

test-run: build-extension build-test
	docker exec \
		fetchq \
		psql \
			-v ON_ERROR_STOP=1 \
			-h localhost \
			--username fetchq \
			--dbname fetchq \
			-a -f /tests/fetchq--${version}.test.sql

test: test-start-pg test-start-delay test-run test-stop
