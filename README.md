pg_dbo_timestamp
==================

PostgreSQL extension for storing time and author of database structure modification.

Dependencies
------------

 * PostgreSQL 9.3+

PostgreSQL install
-------

```sh
sudo make install
```

Database install
---------------

PostgreSQL has a [bug](https://www.postgresql.org/message-id/20170913075559.25630.41587@wrigleys.postgresql.org) that does not allow event trigger activation in extensions. In this regard, when we create the extension, we disable it. For correct operation of the extension after its installation, you must manually enable the event trigger. 

Full installation code:

```sql
CREATE EXTENSION pg_dbo_timestamp [SCHEMA schema_name];
ALTER EVENT TRIGGER dbots_tg_on_ddl_event ENABLE;
```

Usage privileges
---------------

Users of the extension (i.e. pgCodeKeeper users) must have sufficient privileges to read from `dbots_object_timestamps` view.

```sql
GRANT SELECT ON [schema_name.]dbots_object_timestamps TO user_name;
```

Database users executing DDL statements must have sufficient privileges to read from and write to `dbots_event_data` table. Otherwise no DDL events will be recorded and object timestamps will become stale, potentially breaking client functionality.


```sql
GRANT SELECT, INSERT, UPDATE, DELETE ON [schema_name.]dbots_event_data TO user_name;
```

These objects reside in the extension's installation schema, so sufficient privileges to access that schema are also required.

```sql
GRANT USAGE ON SCHEMA schema_name TO user_name;
```

Known issues
----------------

PostgreSQL does not provide full event trigger data for GRANT change events thus we don't track object privileges changes. Instead, we select current ACLs for each object, returned by `dbots_object_timestamps` view.

Updating extension
----------------

Updating the version of extension installed in a database
is done using ALTER EXTENSION.

```sql
ALTER EXTENSION pg_dbo_timestamp UPDATE [ TO '0.1.1'];
```

The target version needs to be installed on the system first
(see Install section).

If the "TO 'x.y.z'" part is omitted, the extension will be updated to the
latest installed version.

Updates are performed by PostgreSQL by loading one or more migration scripts
as needed to go from the installed version S to the target version T.
All migration scripts are in the "extension" directory of PostgreSQL:

```sh
ls `pg_config --sharedir`/extension/pg_dbo_timestamp*
```

Extension structure:
----------------

- `dbots_tg_on_ddl_event` - event trigger, calls `dbots_on_ddl_event` function for CREATE and ALTER statements.
- `dbots_tg_on_drop_event` - event trigger, calls `dbots_on_drop_event` function for DROP statements.
- `dbots_on_ddl_event` - function, writes to `dbots_event_data` the modification time with its author for created/modified objects.
- `dbots_on_drop_event` - function, removes rows for deleted objects from `dbots_event_data`.
- `dbots_get_object_identity` - function, converts object identifier to a human-readable format.
- `dbots_event_data` - table, contains object identifiers, last modification time and its author.
- `dbots_object_timestamps` - view, shows human-readable format of `dbots_event_data`.

Contributing
----------------

To create new version:
1. Modify files in [pgCodeKeeper](https://github.com/pgcodekeeper/pgcodekeeper) project in DATABASE folder.
2. Run `.\generate.sh x.y.z` to generate scripts for new version, where 'x.y.z' is new version series.
3. Change the default version in `pg_dbo_timestamp.control` file.
4. Create a new tag.
