
-- UPSERTS A DOMAIN AND APPARENTLY HANDLES CONCURRENT ACCESS
-- returns:
-- { domain_id: '1' }
DROP FUNCTION IF EXISTS fetchq_get_queue_id(CHARACTER VARYING);
CREATE OR REPLACE FUNCTION fetchq_get_queue_id (
	PAR_domainStr VARCHAR(15),
	OUT queue_id BIGINT
) AS
$BODY$
BEGIN
	SELECT id INTO queue_id FROM fetchq_sys_queues
	WHERE name = PAR_domainStr
	LIMIT 1;

	IF queue_id IS NULL THEN
		INSERT INTO fetchq_sys_queues (name, created_at ) VALUES (PAR_domainStr, now())
		ON CONFLICT DO NOTHING
		RETURNING id INTO queue_id;
	END IF;
END;
$BODY$
LANGUAGE plpgsql;
