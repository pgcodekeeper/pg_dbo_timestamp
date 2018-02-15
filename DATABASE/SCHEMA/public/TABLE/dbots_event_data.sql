SET search_path = public, pg_catalog;

CREATE TABLE dbots_event_data (
	classid oid NOT NULL,
	objid oid NOT NULL,
	last_modified timestamp with time zone DEFAULT now() NOT NULL,
	author name DEFAULT "current_user"()
);

--------------------------------------------------------------------------------

ALTER TABLE dbots_event_data
	ADD CONSTRAINT dbots_event_data_pkey PRIMARY KEY (classid, objid);
