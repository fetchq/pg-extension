create extension fetchq;
select * from fetchq_create_queue('foo');
select * from fetchq__foo__documents;
select * from fetchq__foo__metrics;
select * from fetchq__foo__errors;
select * from fetchq_drop_queue('foo');
drop extension fetchq;