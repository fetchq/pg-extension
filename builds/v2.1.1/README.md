# FetchQ v2.1.1

- Fixes bug #26 which prevented `fetchq_metric_compute_all()` to work.

## Migrate from 1.x

From 1.x to 2.x we have to migrate all the Fetchq related tables into the new
designated schema `fetchq_catalog`. This process need to be executed in two
different moments, one with the current 1.x running, the other on 2.1.

### Preparation:

Copy the following functions into your running FetchQ 1.3.x instance:

```SQL
-- Run this on 1.3.x
CREATE OR REPLACE FUNCTION migrate__fetchq__1to2__p1()
RETURNS TABLE (schema TEXT, function TEXT)
AS $$
DECLARE
  VAR_r RECORD;
BEGIN
  -- create 2.x schema
  CREATE SCHEMA IF NOT EXISTS fetchq_catalog;
	
  -- move all tables
  FOR VAR_r IN (
    SELECT 
      'fetchq__' || name || '__documents' as table_data,
      'fetchq__' || name || '__errors' as table_errors,
      'fetchq__' || name || '__metrics' as table_metrics
    FROM public.fetchq_sys_queues
  ) LOOP
    EXECUTE 'ALTER TABLE IF EXISTS public.' || VAR_r.table_data || ' 
    SET SCHEMA fetchq_catalog';

    EXECUTE 'ALTER TABLE IF EXISTS public.' || VAR_r.table_errors || ' 
    SET SCHEMA fetchq_catalog';

    EXECUTE 'ALTER TABLE IF EXISTS public.' || VAR_r.table_metrics || ' 
    SET SCHEMA fetchq_catalog';
  END LOOP;
	
  -- move sys tables
  FOR VAR_r IN (
    SELECT column1 AS table_name 
    FROM (VALUES ('jobs'), ('metrics'), ('metrics_writes'), ('queues')) as t
  ) LOOP
    EXECUTE 'ALTER TABLE IF EXISTS public.fetchq_sys_' || VAR_r.table_name || ' 
    SET SCHEMA fetchq_catalog';
  END LOOP;

  -- remove existing fetchq extension
  DROP EXTENSION fetchq CASCADE;

  -- returns a list of fetchq related functions that may be orphan
  RETURN QUERY
    SELECT quote_ident(n.nspname) as schema , quote_ident(p.proname) as function 
    FROM   pg_catalog.pg_proc p
    JOIN   pg_catalog.pg_namespace n ON n.oid = p.pronamespace 
    WHERE  n.nspname not like 'pg%'
    AND  p.proname LIKE 'fetchq_%';
END;
$$ LANGUAGE plpgsql;

-- Run this on 2.1.x (and after the previous one!)
CREATE OR REPLACE FUNCTION migrate__fetchq__1to2__p2()
RETURNS TABLE (
  queue VARCHAR,
  cnt INTEGER,
  pln INTEGER,
  pnd INTEGER,
  act INTEGER,
  cpl INTEGER,
  kll INTEGER
)
AS $$
DECLARE
  VAR_r RECORD;
BEGIN
  -- init fetchq
  CREATE SCHEMA IF NOT EXISTS fetchq_catalog;
  CREATE EXTENSION IF NOT EXISTS fetchq;
  PERFORM fetchq_init();
  
  -- recreate indexes:
  FOR VAR_r IN
  	SELECT name FROM fetchq_catalog.fetchq_sys_queues
  LOOP
  	PERFORM fetchq_queue_drop_indexes(VAR_r.name);
  	PERFORM fetchq_queue_create_indexes(VAR_r.name);
  END LOOP;
  
  -- run maintenance:
  PERFORM from fetchq_mnt();
  
  -- reset stats and return output:
  RETURN QUERY
  	SELECT * FROM fetchq_metric_reset_all();
END;
$$ LANGUAGE plpgsql;
```

### Migrate the Schema:

With Fetchq 1.x running, execute the first function:

```SQL
SELECT * FROM  migrate__fetchq__1to2__p1();
```

This should create a `fetchq_catalog` schema and move all the Fetchq related
tables in there. It should also uninstall the current Fetchq extension and
provides a list of any public function that is still related to Fetchq.

The list should be void. If not, you may have to remove some functions manually.

### Upgrade to Fetchq 2.1.1

Restart your database service using one of the 2.x images, once the db is up
and running, execute:

```SQL
SELECT * FROM  migrate__fetchq__1to2__p2();
```

This should create the new extension and run some basic maintenance on the queues
data for you. Depending on the amount of data, this could take a while.

If it works fine, it should spit out the current queues' metrics.

### Cleanup

In the last step you should cleanup the migration functions:

```SQL
DROP FUNCTION IF EXISTS migrate__fetchq__1to2__p1();
DROP FUNCTION IF EXISTS migrate__fetchq__1to2__p2();
```

And you should be good to go!

