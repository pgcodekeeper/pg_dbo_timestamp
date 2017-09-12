SET search_path = public, pg_catalog;

CREATE OR REPLACE FUNCTION initial_time_keeper() RETURNS void
    LANGUAGE plpgsql
    AS $$
	DECLARE
		pg_cat_schema	oid;
		inf_schema	oid;
		extension_deps oid[];
	BEGIN
		SELECT n.oid INTO pg_cat_schema FROM pg_namespace n WHERE n.nspname = 'pg_catalog';
		SELECT n.oid INTO inf_schema FROM pg_namespace n WHERE n.nspname = 'information_schema';

		extension_deps := array( SELECT dep.objid FROM pg_catalog.pg_depend dep WHERE refclassid = 'pg_extension'::regclass AND dep.deptype = 'e');

		--clear table, because have unique primary key
		DELETE FROM ddl_events;

		--all schemas
		INSERT INTO ddl_events SELECT 'pg_namespace'::regclass::oid, n.oid, 0, current_timestamp 
		FROM pg_namespace n 
		WHERE n.nspname NOT LIKE 'pg\_%' 
			AND n.nspname != 'information_schema'
			AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_depend dp WHERE dp.objid = n.oid AND dp.deptype = 'e');

		--all extensions
		INSERT INTO ddl_events SELECT 'pg_extension'::regclass::oid, e.oid, 0, current_timestamp 
		FROM pg_extension e;

		-- all types
		INSERT INTO ddl_events SELECT 'pg_type'::regclass::oid, t.oid, 0, current_timestamp 
		FROM pg_type t 
		WHERE t.typisdefined = TRUE 
		    AND (t.typrelid = 0 OR (SELECT c.relkind FROM pg_catalog.pg_class c WHERE c.oid = t.typrelid) = 'c')
		    AND NOT EXISTS(SELECT 1 FROM pg_catalog.pg_type el WHERE el.oid = t.typelem AND el.typarray = t.oid)
		    AND t.typnamespace != pg_cat_schema 
		    AND t.typnamespace != inf_schema
		    AND NOT t.oid = ANY (extension_deps);

		--all functions
		INSERT INTO ddl_events SELECT 'pg_proc'::regclass::oid, p.oid, 0, current_timestamp  
		FROM pg_proc p 
		WHERE p.pronamespace != pg_cat_schema 
			AND p.pronamespace != inf_schema
			AND NOT p.oid = ANY (extension_deps);

		--all tables
		INSERT INTO ddl_events 
		SELECT 'pg_class'::regclass::oid, c.oid, 0, current_timestamp  
		FROM pg_class c
		WHERE c.relkind = 'r'
			AND c.relnamespace != pg_cat_schema 
			AND c.relnamespace != inf_schema
			AND NOT c.oid = ANY (extension_deps);

		--all indeces
		INSERT INTO ddl_events 
		SELECT 'pg_class'::regclass::oid, c.oid, 0, current_timestamp  
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

		
		--all views
		INSERT INTO ddl_events 
		SELECT 'pg_class'::regclass::oid, c.oid, 0, current_timestamp  
		FROM pg_class c
		WHERE c.relkind = 'v'
			AND c.relnamespace != pg_cat_schema 
			AND c.relnamespace != inf_schema
			AND NOT c.oid = ANY (extension_deps);

		--all triggers
		INSERT INTO ddl_events 
		SELECT 'pg_trigger'::regclass::oid, t.oid, 0, current_timestamp  
		FROM pg_catalog.pg_class c
		RIGHT JOIN pg_catalog.pg_trigger t ON c.oid = t.tgrelid
		WHERE (c.relkind = 'r' OR c.relkind = 'v')
			AND t.tgisinternal = FALSE			
			AND c.relnamespace != pg_cat_schema 
			AND c.relnamespace != inf_schema
			AND NOT t.oid = ANY (extension_deps);

		--all rules
		INSERT INTO ddl_events 
		SELECT 'pg_rewrite'::regclass::oid, r.oid, 0, current_timestamp 
		FROM pg_catalog.pg_rewrite r
		JOIN pg_catalog.pg_class c ON c.oid = r.ev_class 
		WHERE 	c.relnamespace != pg_cat_schema 
			AND c.relnamespace != inf_schema
			AND NOT r.oid = ANY (extension_deps)
			AND NOT ((c.relkind = 'v' OR c.relkind = 'm') 
			AND r.ev_type = '1' 
			AND r.is_instead);

		--all sequence
		INSERT INTO ddl_events 
		SELECT 'pg_class'::regclass::oid, c.oid, 0, current_timestamp 
			FROM pg_catalog.pg_class c
			WHERE c.relnamespace != pg_cat_schema 
			AND c.relnamespace != inf_schema
			AND NOT c.oid = ANY (extension_deps)
			AND c.relkind = 'S';
		
	END;
	$$;

