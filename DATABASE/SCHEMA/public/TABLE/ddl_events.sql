SET search_path = public, pg_catalog;

CREATE TABLE ddl_events (
	classid oid NOT NULL,
	objid oid NOT NULL,
	last_modified timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	author name DEFAULT CURRENT_USER
);

--------------------------------------------------------------------------------

ALTER TABLE ddl_events
	ADD CONSTRAINT events_pkey PRIMARY KEY (classid, objid);
