SET search_path = public, pg_catalog;


CREATE OR REPLACE FUNCTION keep_any_command() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
    DECLARE
        r record;
    BEGIN
        FOR r IN SELECT * FROM pg_event_trigger_ddl_commands() LOOP
            IF EXISTS (
            SELECT 1 from ddl_events WHERE classid = r.classid 
                AND objid = r.objid 
                AND objsubid = r.objsubid)
            THEN 
                UPDATE ddl_events SET last_modified = current_timestamp WHERE classid = r.classid AND objid = r.objid AND objsubid = r.objsubid;
            ELSE
                INSERT INTO ddl_events SELECT r.classid, r.objid, r.objsubid, current_timestamp;
            END IF;
        END LOOP;
    END;
$$;