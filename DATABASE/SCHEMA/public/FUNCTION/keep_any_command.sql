SET search_path = public, pg_catalog;

CREATE OR REPLACE FUNCTION keep_any_command() RETURNS event_trigger
    LANGUAGE plpgsql
    SET search_path = @extschema@, pg_catalog
    AS $$
    DECLARE
        r record;
    BEGIN
        FOR r IN SELECT * FROM pg_event_trigger_ddl_commands() LOOP
            IF r.classid IS NOT NUll AND r.objid IS NOT NULL 
            THEN
                IF EXISTS (
                SELECT 1 from ddl_events WHERE classid = r.classid AND objid = r.objid)
                THEN 
                    UPDATE ddl_events SET last_modified = DEFAULT WHERE classid = r.classid AND objid = r.objid;
                ELSE
                    INSERT INTO ddl_events (classid, objid) SELECT r.classid, r.objid;
                END IF;
            ELSE 
                RAISE WARNING 'Unsupported operation';
            END IF;
        END LOOP;
    END;
$$;
