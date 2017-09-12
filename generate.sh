#!/bin/bash
unzip -o pgCodeKeeper-cli-*.zip -d generated
> generated/empty.sql
cat generated/empty.sql
./generated/pgcodekeeper-cli.sh -o scripts/pg_dbo_timestamp--0.0.1.sql  DATABASE/ generated/empty.sql 
sed -i '1s/^/\\\echo Use "CREATE EXTENSION pg_dbo_timestamp" to load this file. \\\quit\n\n\n/' scripts/pg_dbo_timestamp--*.sql 
cat triggers.sql >> scripts/pg_dbo_timestamp--*.sql 