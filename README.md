pg_dbo_timestamp
==================

PostgreSQL extension for storing time and author of database structure modification.

Dependencies
------------

 * PostgreSQL 9.3+

Install
-------

```sh
sudo make install
```


Enable database
---------------

Postgres has a [bug](https://www.postgresql.org/message-id/20170913075559.25630.41587@wrigleys.postgresql.org) that does not allow the use of event trigger in extension. In this regard, when we create the extension, we disable it. For the correct operation of the extension after its installation, you must manually enable the event trigger. 

Full installation code:

```sql
CREATE EXTENSION pg_dbo_timestamp [SCHEMA schema_name];
ALTER EVENT TRIGGER keep_ddl_timestamps ENABLE;
```

Update extension
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
