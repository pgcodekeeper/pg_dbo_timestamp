SET search_path = public, pg_catalog;

CREATE OR REPLACE FUNCTION dbots_get_object_identity(classid oid, objid oid, subid integer = 0) RETURNS TABLE(type text, schema text, name text, identity text)
    LANGUAGE plpgsql
    SET search_path TO public, pg_catalog
    AS $$
BEGIN
    RETURN QUERY 
    SELECT t.type, t.schema, t.name, t.identity 
    FROM pg_catalog.pg_identify_object(classid, objid, subid) t;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'pg_dbo_timestamp: Object with classid: % and objid: % not found', classid, objid;
END;
$$;
