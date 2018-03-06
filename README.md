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
```sql
CREATE EXTENSION pg_dbo_timestamp [SCHEMA schema_name];
```

Usage privileges
---------------

Users of the extension (i.e. pgCodeKeeper users) must have sufficient privileges to read from `dbots_object_timestamps` view.

Database users executing DDL statements must have sufficient privileges to read from and write to `dbots_event_data` table. Otherwise no DDL events will be recorded and object timestamps will become stale, potentially breaking client functionality.

These objects reside in the extension's installation schema, so sufficient privileges to access that schema are also required.

Known issues
----------------

The object timestamp tracking functionality is not fully reliable at the moment.  
PostgreSQL does not provide full event trigger data for GRANT change events thus we don't track object privileges changes.

Updating extension
----------------

Updating the version of extension installed in a database
is done using ALTER EXTENSION.

```sql
ALTER EXTENSION pg_dbo_timestamp UPDATE TO '0.1.1';
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
