SET search_path = public, pg_catalog;

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
