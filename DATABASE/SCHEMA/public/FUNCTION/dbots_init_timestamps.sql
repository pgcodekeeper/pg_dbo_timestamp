SET search_path = public, pg_catalog;

CREATE OR REPLACE FUNCTION dbots_init_timestamps() RETURNS void
    LANGUAGE plpgsql
    SET search_path TO public, pg_catalog
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
	WHERE 	c.relnamespace != pg_cat_schema 
		AND c.relnamespace != inf_schema
		AND NOT r.oid = ANY (extension_deps)
		AND NOT (c.relkind IN ('v', 'm') AND r.ev_type = '1' AND r.is_instead);
		
    --all fts parsers
    INSERT INTO dbots_event_data (classid, objid, ses_user, cur_user, ip_address)
    SELECT 'pg_catalog.pg_ts_parser'::pg_catalog.regclass::oid, p.oid, null, null, null
    FROM pg_catalog.pg_ts_parser p
    WHERE p.prsnamespace != pg_cat_schema
        AND p.prsnamespace != inf_schema
        AND NOT t.oid = ANY (extension_deps);
        
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

END;
	$$;
