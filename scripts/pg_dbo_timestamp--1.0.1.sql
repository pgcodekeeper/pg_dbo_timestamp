\echo Use "CREATE EXTENSION pg_dbo_timestamp" to load this file. \quit
SET check_function_bodies = false;



CREATE OR REPLACE FUNCTION dbots_get_object_identity(classid oid, objid oid, subid integer = 0) RETURNS TABLE(type text, schema text, name text, identity text)
    LANGUAGE plpgsql
    SET search_path TO @extschema@, pg_catalog
    AS $$
BEGIN
    RETURN QUERY 
    SELECT t.type, t.schema, t.name, t.identity 
    FROM pg_catalog.pg_identify_object(classid, objid, subid) t;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'pg_dbo_timestamp: Object with classid: %, objid: %, subid: % not found', classid, objid, subid;
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

CREATE TABLE dbots_event_data (
	classid oid NOT NULL,
	objid oid NOT NULL,
	last_modified timestamp with time zone DEFAULT pg_catalog.now() NOT NULL,
	cur_user name DEFAULT pg_catalog."current_user"(),
	ses_user name DEFAULT pg_catalog."session_user"(),
	ip_address text DEFAULT pg_catalog.inet_client_addr()
);

ALTER TABLE dbots_event_data
	ADD CONSTRAINT dbots_event_data_pkey PRIMARY KEY (classid, objid);

CREATE VIEW dbots_object_timestamps AS
	WITH acls AS (
     SELECT union_acls.tableoid,
        union_acls.oid,
        union_acls.acl,
        union_acls.colnames,
        union_acls.colacls
       FROM ( SELECT pg_proc.tableoid,
                pg_proc.oid,
                pg_proc.proacl,
                NULL::text[] AS text,
                NULL::text[] AS text
               FROM pg_catalog.pg_proc
            UNION ALL
             SELECT pg_namespace.tableoid,
                pg_namespace.oid,
                pg_namespace.nspacl,
                NULL::text[] AS text,
                NULL::text[] AS text
               FROM pg_catalog.pg_namespace
            UNION ALL
             SELECT pg_type.tableoid,
                pg_type.oid,
                pg_type.typacl,
                NULL::text[] AS text,
                NULL::text[] AS text
               FROM pg_catalog.pg_type
            UNION ALL
             SELECT c.tableoid,
                c.oid,
                c.relacl,
                attrs.attnames,
                attrs.attacls
               FROM (pg_catalog.pg_class c
                 LEFT JOIN ( SELECT attr.attrelid,
                        array_agg(attr.attname ORDER BY attr.attnum) AS attnames,
                        array_agg((attr.attacl)::text ORDER BY attr.attnum) AS attacls
                       FROM pg_catalog.pg_attribute attr
                      WHERE ((attr.attnum > 0) AND (attr.attisdropped IS FALSE) AND (attr.attacl IS NOT NULL))
                      GROUP BY attr.attrelid) attrs ON ((c.oid = attrs.attrelid)))) union_acls(tableoid, oid, acl, colnames, colacls)
      WHERE ((union_acls.acl IS NOT NULL) OR (union_acls.colacls IS NOT NULL))
 )
 SELECT (a.acl)::text AS acl,
    a.colnames,
    a.colacls,
    t.objid,
    f.type,
    f.schema,
    f.name,
    f.identity,
    t.last_modified,
    t.ses_user,
    t.cur_user,
    t.ip_address
 FROM (dbots_event_data t
 LEFT JOIN acls a ON (((a.tableoid = t.classid) AND (a.oid = t.objid)))),
 LATERAL dbots_get_object_identity(t.classid, t.objid) f(type, schema, name, identity);

CREATE EVENT TRIGGER dbots_tg_on_drop_event ON sql_drop
   EXECUTE PROCEDURE dbots_on_drop_event();

CREATE EVENT TRIGGER dbots_tg_on_ddl_event ON ddl_command_end
   EXECUTE PROCEDURE dbots_on_ddl_event();

ALTER EVENT TRIGGER dbots_tg_on_ddl_event DISABLE;
