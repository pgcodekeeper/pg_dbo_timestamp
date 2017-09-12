SET search_path = public, pg_catalog;


CREATE OR REPLACE FUNCTION keep_any_command() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
    DECLARE
        new_classid oid;
        new_objid   oid;
        new_objsubid    integer;
    BEGIN
        SELECT classid, objid, objsubid
        INTO new_classid, new_objid, new_objsubid
        FROM pg_event_trigger_ddl_commands();

        IF 
            new_classid IS NOT NULL
        THEN
            IF EXISTS (
            SELECT 1 from ddl_events WHERE classid = new_classid 
                AND objid = new_objid 
                AND objsubid = new_objsubid)
            THEN 
                UPDATE ddl_events SET last_modified = current_timestamp WHERE classid = new_classid AND objid = new_objid AND objsubid = new_objsubid;
            ELSE
                INSERT INTO ddl_events SELECT new_classid, new_objid, new_objsubid, current_timestamp;
            END IF;
        END IF;
    END;
$$;
