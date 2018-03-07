SET search_path = public, pg_catalog;

CREATE TABLE dbots_event_data (
	classid oid NOT NULL,
	objid oid NOT NULL,
	last_modified timestamp with time zone DEFAULT pg_catalog.now() NOT NULL,
	cur_user name DEFAULT pg_catalog."current_user"(),
	ses_user name DEFAULT pg_catalog."session_user"(),
	ip_address text DEFAULT pg_catalog.inet_client_addr()
);

--------------------------------------------------------------------------------

ALTER TABLE dbots_event_data
	ADD CONSTRAINT dbots_event_data_pkey PRIMARY KEY (classid, objid);
