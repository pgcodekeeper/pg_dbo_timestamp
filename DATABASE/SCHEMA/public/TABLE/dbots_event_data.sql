SET search_path = public, pg_catalog;

CREATE TABLE dbots_event_data (
	classid oid NOT NULL,
	objid oid NOT NULL,
	last_modified timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
	author name DEFAULT CURRENT_USER
);

--------------------------------------------------------------------------------

ALTER TABLE dbots_event_data
	ADD CONSTRAINT events_pkey PRIMARY KEY (classid, objid);
