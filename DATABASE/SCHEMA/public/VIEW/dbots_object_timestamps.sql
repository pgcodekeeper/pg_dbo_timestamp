SET search_path = public, pg_catalog;

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
