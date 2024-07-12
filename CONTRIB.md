# Contributing to Fetchq

## Run for Development

```bash
# Single shot
make test

# Operate the db instance
make start
make stop

# Run unit tests
make test-run
```

## Unit Tests

> 🔥 The testing system is custom made 🔥  
> <small>(I was young and stupid, and I didn't know PGTap)</small>

Open the file `tests/_run.sql`.

In the end of the file you find the top-level instructions to run different groups of test.

In any test, use `RAISE NOTICE` to log stuff:

```sql
RAISE NOTICE E'\nMy beautiful log';
```

## Updating FetchQ Version

- Makefile
- src/fetchq.control