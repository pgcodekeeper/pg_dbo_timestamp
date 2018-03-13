SET search_path = public, pg_catalog;

CREATE OR REPLACE FUNCTION dbots_on_drop_event() RETURNS event_trigger
    LANGUAGE plpgsql
    SET search_path TO public, pg_catalog
    AS $$
DECLARE
    r record;
    _exstate text;
    _exmsg text;
    _exctx text;
BEGIN
    FOR r IN SELECT * FROM pg_catalog.pg_event_trigger_dropped_objects() f WHERE NOT f.is_temporary LOOP
        -- skip objsubid drops, write column drops as table updates 
        IF r.objsubid = 0
        THEN
            DELETE FROM dbots_event_data 
            WHERE classid = r.classid AND objid = r.objid;
        ELSE
            UPDATE dbots_event_data SET last_modified = DEFAULT, cur_user = DEFAULT,
                ses_user = DEFAULT, ip_address = DEFAULT
            WHERE classid = r.classid AND objid = r.objid;
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
