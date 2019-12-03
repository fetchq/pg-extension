
-- provides a full JSON rapresentation of the event
CREATE OR REPLACE FUNCTION fetchq_trigger_notify_as_json () RETURNS TRIGGER AS $$
DECLARE
	rec RECORD;
    payload TEXT;
    new_data TEXT;
    old_data TEXT;
BEGIN
    -- Set record row depending on operation
    CASE TG_OP
    WHEN 'INSERT' THEN
        rec := NEW;
        new_data = row_to_json(NEW);
        old_data := 'null';
    WHEN 'UPDATE' THEN
        rec := NEW;
        new_data = row_to_json(NEW);
        old_data := row_to_json(OLD);
    WHEN 'DELETE' THEN
        rec := OLD;
        SELECT json_agg(n)::text INTO old_data FROM json_each_text(to_json(OLD)) n;
        old_data := row_to_json(OLD);
        new_data := 'null';
    ELSE
        RAISE EXCEPTION 'Unknown TG_OP: "%". Should not occur!', TG_OP;
    END CASE;

    -- Record to JSON
    

    -- Build the payload
    payload := ''
            || '{'
            || '"timestamp":"' || CURRENT_TIMESTAMP                    || '",'
            || '"operation":"' || TG_OP                                || '",'
            || '"schema":"'    || TG_TABLE_SCHEMA                      || '",'
            || '"table":"'     || TG_TABLE_NAME                        || '",'
            || '"new_data":'   || new_data                             || ','
            || '"old_data":'   || old_data
            || '}';

    -- Notify and return
    PERFORM pg_notify('fetchq_on_change', payload);
	RETURN rec;
END; $$
LANGUAGE plpgsql;
