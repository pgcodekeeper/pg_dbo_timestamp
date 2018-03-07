\echo Use "UPDATE EXTENSION pg_dbo_timestamp TO $NEW_VERSION" to load this file. \quit
SET check_function_bodies = false;



-- DEPCY: This VIEW depends on the COLUMN: dbots_event_data.author

DROP VIEW dbots_object_timestamps;

ALTER TABLE dbots_event_data
	DROP COLUMN author;

CREATE OR REPLACE FUNCTION dbots_get_object_identity(classid oid, objid oid) RETURNS TABLE(type text, schema text, name text, identity text)
    LANGUAGE plpgsql
    SET search_path TO @extschema@, pg_catalog
    AS $$
BEGIN
    BEGIN
        RETURN QUERY 
        SELECT t.type, t.schema, t.name, t.identity 
        FROM pg_catalog.pg_identify_object(classid, objid, 0) t;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'pg_dbo_timestamp: Object with classid: % and objid: % not found', classid, objid;
    END;
END;
$$;

CREATE OR REPLACE FUNCTION dbots_init_timestamps() RETURNS void
    LANGUAGE plpgsql
    SET search_path TO @extschema@, pg_catalog
    AS $$
DECLARE
	pg_cat_schema  oid;
	inf_schema	   oid;
	extension_deps oid[];
BEGIN
	SELECT n.oid INTO pg_cat_schema FROM pg_catalog.pg_namespace n WHERE n.nspname = 'pg_catalog';
	SELECT n.oid INTO inf_schema FROM pg_catalog.pg_namespace n WHERE n.nspname = 'information_schema';

	extension_deps := array( SELECT dep.objid FROM pg_catalog.pg_depend dep WHERE refclassid = 'pg_catalog.pg_extension'::pg_catalog.regclass AND dep.deptype = 'e');

	--clear table, because have unique primary key
	DELETE FROM dbots_event_data;

	--all schemas
	INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address) 
	SELECT 'pg_catalog.pg_namespace'::pg_catalog.regclass::oid, n.oid, null, null, null
	FROM pg_catalog.pg_namespace n 
	WHERE n.nspname NOT LIKE 'pg\_%' 
		AND n.nspname != 'information_schema'
		AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_depend dp WHERE dp.objid = n.oid AND dp.deptype = 'e');

	--all extensions
	INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address) 
	SELECT 'pg_catalog.pg_extension'::pg_catalog.regclass::oid, e.oid, null, null, null
	FROM pg_catalog.pg_extension e;

	-- all types
	INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address) 
	SELECT 'pg_catalog.pg_type'::pg_catalog.regclass::oid, t.oid, null, null, null
	FROM pg_catalog.pg_type t 
	WHERE t.typisdefined = TRUE 
	    AND (t.typrelid = 0 OR (SELECT c.relkind FROM pg_catalog.pg_class c WHERE c.oid = t.typrelid) = 'c')
	    AND NOT EXISTS(SELECT 1 FROM pg_catalog.pg_type el WHERE el.oid = t.typelem AND el.typarray = t.oid)
	    AND t.typnamespace != pg_cat_schema 
	    AND t.typnamespace != inf_schema
	    AND NOT t.oid = ANY (extension_deps);

	--all functions
	INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address) 
	SELECT 'pg_catalog.pg_proc'::regclass::oid, p.oid, null, null, null
	FROM pg_catalog.pg_proc p 
	WHERE p.pronamespace != pg_cat_schema 
		AND p.pronamespace != inf_schema
		AND NOT p.oid = ANY (extension_deps);

	--all relations
	INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address) 
	SELECT 'pg_catalog.pg_class'::pg_catalog.regclass::oid, c.oid, null, null, null
	FROM pg_catalog.pg_class c
	WHERE c.relkind NOT IN ('i','t')
		AND c.relnamespace != pg_cat_schema 
		AND c.relnamespace != inf_schema
		AND NOT c.oid = ANY (extension_deps);

	--all indices
	INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address) 
	SELECT 'pg_catalog.pg_class'::pg_catalog.regclass::oid, c.oid, null, null, null
	FROM pg_catalog.pg_index ind
	JOIN pg_catalog.pg_class c ON c.oid = ind.indexrelid
	LEFT JOIN pg_catalog.pg_constraint cons ON cons.conindid = ind.indexrelid
		AND cons.contype IN ('p', 'u', 'x')
	WHERE c.relkind = 'i'
		AND c.relnamespace != pg_cat_schema 
		AND c.relnamespace != inf_schema
		AND NOT c.oid = ANY (extension_deps)
		AND ind.indisprimary = FALSE
		AND ind.indisexclusion = FALSE
		AND cons.conindid is NULL;	

	--all triggers
	INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address) 
	SELECT 'pg_catalog.pg_trigger'::pg_catalog.regclass::oid, t.oid, null, null, null
	FROM pg_catalog.pg_class c
	RIGHT JOIN pg_catalog.pg_trigger t ON c.oid = t.tgrelid
	WHERE c.relkind IN ('r', 'f', 'p', 'm', 'v')
		AND t.tgisinternal = FALSE			
		AND c.relnamespace != pg_cat_schema 
		AND c.relnamespace != inf_schema
		AND NOT t.oid = ANY (extension_deps);

	--all rules
	INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address) 
	SELECT 'pg_catalog.pg_rewrite'::pg_catalog.regclass::oid, r.oid, null, null, null
	FROM pg_catalog.pg_rewrite r
	JOIN pg_catalog.pg_class c ON c.oid = r.ev_class 
	WHERE 	c.relnamespace != pg_cat_schema 
		AND c.relnamespace != inf_schema
		AND NOT r.oid = ANY (extension_deps)
		AND NOT (c.relkind IN ('v', 'm') AND r.ev_type = '1' AND r.is_instead);
		
END;
	$$;

CREATE OR REPLACE FUNCTION dbots_on_ddl_event() RETURNS event_trigger
    LANGUAGE plpgsql
    SET search_path TO @extschema@, pg_catalog
    AS $$
DECLARE
    r record;
    _exstate text;
    _exmsg text;
    _exctx text;
BEGIN
    FOR r IN SELECT * FROM pg_catalog.pg_event_trigger_ddl_commands() LOOP
        IF r.classid IS NOT NUll AND r.objid IS NOT NULL 
        THEN
            IF EXISTS (
            SELECT 1 from dbots_event_data WHERE classid = r.classid AND objid = r.objid)
            THEN 
                UPDATE dbots_event_data SET last_modified = DEFAULT, cur_user = DEFAULT,
                ses_user = DEFAULT, ip_address = DEFAULT
                WHERE classid = r.classid AND objid = r.objid;
            ELSE
                INSERT INTO dbots_event_data (classid, objid) SELECT r.classid, r.objid;
            END IF;
        ELSE 
            RAISE NOTICE 'DDL unsupported by pg_dbo_timestamp';
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

CREATE OR REPLACE FUNCTION dbots_on_drop_event() RETURNS event_trigger
    LANGUAGE plpgsql
    SET search_path TO @extschema@, pg_catalog
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

ALTER TABLE dbots_event_data
	ADD COLUMN cur_user name;

ALTER TABLE ONLY dbots_event_data
	ALTER COLUMN cur_user SET DEFAULT pg_catalog."current_user"();

ALTER TABLE dbots_event_data
	ADD COLUMN ses_user name;

ALTER TABLE ONLY dbots_event_data
	ALTER COLUMN ses_user SET DEFAULT pg_catalog."session_user"();

ALTER TABLE dbots_event_data
	ADD COLUMN ip_address text;

ALTER TABLE ONLY dbots_event_data
	ALTER COLUMN ip_address SET DEFAULT pg_catalog.inet_client_addr();

ALTER TABLE ONLY dbots_event_data
	ALTER COLUMN last_modified SET DEFAULT pg_catalog.now();

CREATE VIEW dbots_object_timestamps AS
	SELECT 
            t.objid,
            f.type,
            f.schema,
            f.name,
            f.identity,
            t.last_modified,
            t.ses_user,
            t.cur_user, 
            t.ip_address
    FROM dbots_event_data t,
            LATERAL dbots_get_object_identity(t.classid, t.objid) f(type, schema, name, identity);

ALTER EVENT TRIGGER dbots_tg_on_ddl_event ENABLE;