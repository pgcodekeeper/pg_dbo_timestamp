SET search_path = public, pg_catalog;

CREATE OR REPLACE FUNCTION keep_drop_command() RETURNS event_trigger
    LANGUAGE plpgsql
    SET search_path = public, pg_catalog
    AS $$
    DECLARE
        r record;
        _exstate text;
        _exmsg text;
        _exctx text;
    BEGIN
        FOR r IN SELECT * FROM pg_event_trigger_dropped_objects() LOOP 
            IF NOT r.is_temporary 
            THEN
                DELETE FROM ddl_events 
                WHERE classid = r.classid 
                    AND objid = r.objid;
            END IF; 
        END LOOP;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS 
            _exstate = RETURNED_SQLSTATE,
            _exmsg = MESSAGE_TEXT,
            _exctx = PG_EXCEPTION_CONTEXT;
        RAISE WARNING 'Error in pg_dbo_timestamp event trigger function. state: %, message: %, context: %', 
            _exstate, _exmsg, _exctx;
    END;
$$;