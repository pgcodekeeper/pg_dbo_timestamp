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

CREATE OR REPLACE FUNCTION dbots_init_timestamps() RETURNS void
    LANGUAGE plpgsql
    SET search_path TO @extschema@, pg_catalog
    AS $$
DECLARE
    pg_cat_schema  oid;
    inf_schema     oid;
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
    SELECT 'pg_catalog.pg_proc'::pg_catalog.regclass::oid, p.oid, null, null, null
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
    WHERE   c.relnamespace != pg_cat_schema 
        AND c.relnamespace != inf_schema
        AND NOT r.oid = ANY (extension_deps)
        AND NOT (c.relkind IN ('v', 'm') AND r.ev_type = '1' AND r.is_instead);
        
    --all fts parsers
    INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address)
    SELECT 'pg_catalog.pg_ts_parser'::pg_catalog.regclass::oid, p.oid, null, null, null
    FROM pg_catalog.pg_ts_parser p
    WHERE p.prsnamespace != pg_cat_schema
        AND p.prsnamespace != inf_schema
        AND NOT p.oid = ANY (extension_deps);
        
    --all fts templates
    INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address)
    SELECT 'pg_catalog.pg_ts_template'::pg_catalog.regclass::oid, t.oid, null, null, null
    FROM pg_catalog.pg_ts_template t
    WHERE t.tmplnamespace != pg_cat_schema
        AND t.tmplnamespace != inf_schema
        AND NOT t.oid = ANY (extension_deps);
        
    --all fts dictionaries
    INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address)
    SELECT 'pg_catalog.pg_ts_dict'::pg_catalog.regclass::oid, d.oid, null, null, null
    FROM pg_catalog.pg_ts_dict d
    WHERE d.dictnamespace != pg_cat_schema
        AND d.dictnamespace != inf_schema
        AND NOT d.oid = ANY (extension_deps);
        
    --all fts configurations
    INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address)
    SELECT 'pg_catalog.pg_ts_config'::pg_catalog.regclass::oid, c.oid, null, null, null
    FROM pg_catalog.pg_ts_config c
    WHERE c.cfgnamespace != pg_cat_schema
        AND c.cfgnamespace != inf_schema
        AND NOT c.oid = ANY (extension_deps);
      
    --all collations
    INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address)
    SELECT 'pg_catalog.pg_collation'::pg_catalog.regclass::oid, c.oid, null, null, null
    FROM pg_catalog.pg_collation c
    WHERE c.collnamespace != pg_cat_schema
        AND c.collnamespace != inf_schema
        AND NOT c.oid = ANY (extension_deps);

    --all casts
    INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address) 
    SELECT 'pg_catalog.pg_cast'::pg_catalog.regclass::oid, c.oid::bigint,
    null, null, null
    FROM pg_catalog.pg_cast c
    WHERE NOT c.oid = ANY (extension_deps);

    --all fdws       
    INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address)
    SELECT 'pg_catalog.pg_foreign_data_wrapper'::pg_catalog.regclass::oid, fdw.oid, null, null, null
    FROM pg_catalog.pg_foreign_data_wrapper fdw
    WHERE NOT fdw.oid = ANY (extension_deps);

    --all servers
    INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address)
    SELECT 'pg_catalog.pg_foreign_server'::pg_catalog.regclass::oid,
    srv.oid, null, null, null
    FROM pg_catalog.pg_foreign_server srv
    WHERE NOT srv.oid = ANY (extension_deps);
        
    --all operators
    INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address)
    SELECT 'pg_catalog.pg_operator'::pg_catalog.regclass::oid,
    o.oid::bigint, null, null, null
    FROM pg_catalog.pg_operator o
        WHERE o.oprnamespace != pg_cat_schema
        AND o.oprnamespace != inf_schema
        AND NOT o.oid = ANY (extension_deps);
        
    --all policies
    INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address) 
    SELECT 'pg_catalog.pg_policy'::pg_catalog.regclass::oid, p.oid::bigint,
    null, null, null
    FROM pg_catalog.pg_policy p
    LEFT JOIN pg_catalog.pg_class c ON c.oid = p.polrelid
    WHERE c.relnamespace != pg_cat_schema 
        AND c.relnamespace != inf_schema
        AND NOT p.oid = ANY (extension_deps);

    --all sequences
    INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address) 
    SELECT 'pg_catalog.pg_sequence'::pg_catalog.regclass::oid, s.seqrelid::bigint,
    null, null, null
    FROM pg_catalog.pg_sequence s
    LEFT JOIN pg_catalog.pg_class c ON c.oid = s.seqrelid
    WHERE c.relnamespace != pg_cat_schema 
        AND c.relnamespace != inf_schema
        AND NOT s.seqrelid = ANY (extension_deps);

    --all conversions
    INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address) 
    SELECT 'pg_catalog.pg_conversion'::pg_catalog.regclass::oid, c.oid::bigint,
    null, null, null
    FROM pg_catalog.pg_conversion c
    WHERE c.connamespace != pg_cat_schema 
        AND c.connamespace != inf_schema
        AND NOT c.oid = ANY (extension_deps);

    --all event triggers
    INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address) 
    SELECT 'pg_catalog.pg_event_trigger'::pg_catalog.regclass::oid, ev.oid::bigint,
    null, null, null
    FROM pg_catalog.pg_event_trigger ev
    WHERE NOT ev.oid = ANY (extension_deps);
    
    --all language
    INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address) 
    SELECT 'pg_catalog.pg_language'::pg_catalog.regclass::oid, lan.oid::bigint,
    null, null, null
    FROM pg_catalog.pg_language lan
    WHERE NOT lan.oid = ANY (extension_deps);

    --all operator classes
    INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address) 
    SELECT 'pg_catalog.pg_opclass'::pg_catalog.regclass::oid, op.oid::bigint,
    null, null, null
    FROM pg_catalog.pg_opclass op
    WHERE op.opcnamespace != pg_cat_schema 
        AND op.opcnamespace != inf_schema
        AND NOT op.oid = ANY (extension_deps);
        
    --all operator families
    INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address) 
    SELECT 'pg_catalog.pg_opfamily'::pg_catalog.regclass::oid, opf.oid::bigint,
    null, null, null
    FROM pg_catalog.pg_opfamily opf
    WHERE opf.opfnamespace != pg_cat_schema 
        AND opf.opfnamespace != inf_schema
        AND NOT opf.oid = ANY (extension_deps);
        
    --all procedures
    INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address) 
    SELECT 'pg_catalog.pg_proc'::pg_catalog.regclass::oid, proc.oid::bigint,
    null, null, null
    FROM pg_catalog.pg_proc proc
    WHERE proc.pronamespace != pg_cat_schema 
        AND proc.pronamespace != inf_schema
        AND NOT proc.oid = ANY (extension_deps);

    --all publications
    INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address) 
    SELECT 'pg_catalog.pg_proc'::pg_catalog.regclass::oid, p.oid::bigint,
    null, null, null
    FROM pg_catalog.pg_publication p
    WHERE NOT p.oid = ANY (extension_deps);

    --all statistics
    INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address) 
    SELECT 'pg_catalog.pg_statistic'::pg_catalog.regclass::oid, s.starelid::bigint,
    null, null, null
    FROM pg_catalog.pg_statistic s
    LEFT JOIN pg_catalog.pg_class c ON c.oid = s.starelid
    WHERE c.relnamespace != pg_cat_schema 
        AND c.relnamespace != inf_schema
        AND NOT s.starelid = ANY (extension_deps);
    
     --all tablespaces
    INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address) 
    SELECT 'pg_catalog.pg_tablespace'::pg_catalog.regclass::oid, t.oid::bigint,
    null, null, null
    FROM pg_catalog.pg_tablespace t
    WHERE NOT t.oid = ANY (extension_deps);
    
     --all transforms
    INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address) 
    SELECT 'pg_catalog.pg_transform'::pg_catalog.regclass::oid, t.oid::bigint,
    null, null, null
    FROM pg_catalog.pg_transform t
    WHERE NOT t.oid = ANY (extension_deps); 
    
    --all subscription
    INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address) 
    SELECT 'pg_catalog.pg_statistic'::pg_catalog.regclass::oid, s.oid::bigint,
    null, null, null
    FROM pg_catalog.pg_subscription s
    WHERE NOT s.oid = ANY (extension_deps);
    
    --all user mappings
    INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address) 
    SELECT 'pg_catalog.pg_user_mapping'::pg_catalog.regclass::oid, um.oid::bigint,
    null, null, null
    FROM pg_catalog.pg_user_mapping um
    WHERE NOT um.oid = ANY (extension_deps);
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

SELECT dbots_init_timestamps();

ALTER EVENT TRIGGER dbots_tg_on_ddl_event DISABLE;
