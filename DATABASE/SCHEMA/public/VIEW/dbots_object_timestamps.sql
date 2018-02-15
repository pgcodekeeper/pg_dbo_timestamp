SET search_path = public, pg_catalog;

CREATE VIEW dbots_object_timestamps AS
    SELECT 
            t.objid,
            f.type,
            f.schema,
            f.name,
            f.identity,
            t.last_modified,
            t.author
   FROM dbots_event_data t,
            LATERAL pg_identify_object(t.classid, t.objid, 0) f(type, schema, name, identity);
