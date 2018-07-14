
CREATE OR REPLACE FUNCTION fetchq_trigger_docs_notify_insert () RETURNS TRIGGER AS $$
DECLARE
	VAR_event VARCHAR = 'pnd';
BEGIN
	IF NEW.next_iteration > NOW() THEN
		VAR_event = 'pln';
	END IF;
	
	PERFORM pg_notify(FORMAT('%s__%s', TG_TABLE_NAME::regclass::text, VAR_event), NEW.subject);
	RETURN NEW;
END; $$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fetchq_trigger_docs_notify_update () RETURNS TRIGGER AS $$
DECLARE
	VAR_event VARCHAR = 'null';
BEGIN
	IF NEW.status = 0 THEN
		VAR_event = 'pln';
	END IF;

    IF NEW.status = 1 THEN
		VAR_event = 'pnd';
	END IF;

    IF NEW.status = 2 THEN
		VAR_event = 'act';
	END IF;

    IF NEW.status = 3 THEN
		VAR_event = 'cpl';
	END IF;

    IF NEW.status = -1 THEN
		VAR_event = 'kll';
	END IF;
	
	PERFORM pg_notify(FORMAT('%s__%s', TG_TABLE_NAME::regclass::text, VAR_event), NEW.subject);
	RETURN NEW;
END; $$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION fetchq_queue_disable_notify (
    PAR_queue VARCHAR,
    OUT success BOOLEAN
) AS $$
DECLARE
	VAR_q VARCHAR;
BEGIN
	-- after insert
    VAR_q = 'DROP TRIGGER IF EXISTS fetchq__%s__triggers_notify_insert ON fetchq__%s__documents';
    VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue);
    EXECUTE VAR_q;

    -- after update
    VAR_q = 'DROP TRIGGER IF EXISTS fetchq__%s__triggers_notify_update ON fetchq__%s__documents';
    VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue);
    EXECUTE VAR_q;

END; $$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fetchq_queue_enable_notify (
    PAR_queue VARCHAR,
    OUT success BOOLEAN
) AS $$
DECLARE
	VAR_q VARCHAR;
BEGIN
	-- drop existing
    PERFORM fetchq_queue_disable_notify(PAR_queue);
    
    -- after insert
    VAR_q = 'CREATE TRIGGER fetchq__%s__triggers_notify_insert AFTER INSERT ';
	VAR_q = VAR_q || 'ON fetchq__%s__documents ';
    VAR_q = VAR_q || 'FOR EACH ROW EXECUTE PROCEDURE fetchq_trigger_docs_notify_insert();';
    VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue);
    EXECUTE VAR_q;

    -- after update
    VAR_q = 'CREATE TRIGGER fetchq__%s__triggers_notify_update AFTER UPDATE ';
	VAR_q = VAR_q || 'ON fetchq__%s__documents ';
    VAR_q = VAR_q || 'FOR EACH ROW EXECUTE PROCEDURE fetchq_trigger_docs_notify_update();';
    VAR_q = FORMAT(VAR_q, PAR_queue, PAR_queue);
    EXECUTE VAR_q;
END; $$
LANGUAGE plpgsql;
