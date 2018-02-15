#!/bin/bash
mkdir -p scripts
unzip -o pgCodeKeeper-cli-*.zip -d generated > /dev/null
echo '\echo Use "CREATE EXTENSION pg_dbo_timestamp" to load this file. \quit' > scripts/pg_dbo_timestamp--0.0.1.sql
./generated/pgcodekeeper-cli.sh DATABASE/ fragments/empty.sql >> scripts/pg_dbo_timestamp--0.0.1.sql 
sed -i "s/SET search_path = public, pg_catalog;//" scripts/pg_dbo_timestamp--0.0.1.sql
sed -i "s/SET search_path = public, pg_catalog/SET search_path = @extschema@, pg_catalog/" scripts/pg_dbo_timestamp--0.0.1.sql
cat fragments/finish_install.sql >> scripts/pg_dbo_timestamp--0.0.1.sql
