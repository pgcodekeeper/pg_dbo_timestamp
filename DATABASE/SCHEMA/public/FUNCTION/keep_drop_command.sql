SET search_path = public, pg_catalog;

CREATE OR REPLACE FUNCTION keep_drop_command() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
	DECLARE
		old_classid	oid;
		old_objid	oid;
		old_objsubid	integer;
		is_temp bool;
	BEGIN
		SELECT classid, objid, objsubid, is_temporary
		INTO old_classid, old_objid, old_objsubid, is_temp
		FROM pg_event_trigger_dropped_objects();

		IF NOT is_temp 
		THEN
			DELETE FROM ddl_events 
			WHERE classid = old_classid 
				AND objid = old_objid 
				AND objsubid = old_objsubid;
		END IF;
	END;
$$;
