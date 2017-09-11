SET search_path = public, pg_catalog;

CREATE TABLE ddl_events (
	classid oid NOT NULL,
	objid oid NOT NULL,
	objsubid integer NOT NULL,
	last_modified timestamp with time zone NOT NULL
);

ALTER TABLE ddl_events OWNER TO CURRENT_USER;

--------------------------------------------------------------------------------

ALTER TABLE ddl_events
	ADD CONSTRAINT ddl_events_pkey PRIMARY KEY (classid, objid, objsubid);
