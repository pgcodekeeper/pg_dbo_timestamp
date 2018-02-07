#!/bin/bash
mkdir -p scripts
unzip -o pgCodeKeeper-cli-*.zip -d generated
./generated/pgcodekeeper-cli.sh -o scripts/pg_dbo_timestamp--0.0.1.sql  DATABASE/ fragments/empty.sql
var='\\\echo Use "CREATE EXTENSION pg_dbo_timestamp" to load this file. \\\quit'
sed -i "1s/.*/$var/" scripts/pg_dbo_timestamp--0.0.1.sql
cat fragments/disable_trigger.sql >> scripts/pg_dbo_timestamp--0.0.1.sql
sed -i 's/ddl_events/@extschema@.ddl_events/g' scripts/pg_dbo_timestamp--0.0.1.sql