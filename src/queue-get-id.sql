
-- UPSERTS A DOMAIN AND APPARENTLY HANDLES CONCURRENT ACCESS
-- returns:
-- { domain_id: '1' }
DROP FUNCTION IF EXISTS fetchq_queue_get_id(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_queue_get_id (
	PAR_queue VARCHAR(15),
	OUT queue_id BIGINT
) AS
$BODY$
BEGIN
	SELECT id INTO queue_id FROM fetchq_sys_queues
	WHERE name = PAR_queue
	LIMIT 1;

	IF queue_id IS NULL THEN
		INSERT INTO fetchq_sys_queues (name, created_at ) VALUES (PAR_queue, now())
		ON CONFLICT DO NOTHING
		RETURNING id INTO queue_id;
	END IF;
END;
$BODY$
LANGUAGE plpgsql;
