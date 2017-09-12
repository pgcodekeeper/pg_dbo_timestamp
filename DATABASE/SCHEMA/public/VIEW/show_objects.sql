SET search_path = public, pg_catalog;

CREATE VIEW show_objects AS
    SELECT f.type,
    f.schema,
    f.name,
    f.identity,
    t.last_modified
   FROM ddl_events t,
    LATERAL pg_identify_object(t.classid, t.objid, t.objsubid) f(type, schema, name, identity);

