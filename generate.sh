#!/bin/bash

if [ "$#" -ne 1 ] 
then
echo "Expected 1 arguments: new_version"
exit 1
fi
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
NEW_VERSION="$1"
LAST_VERSION=`git --git-dir $DIR/.git describe --tags --abbrev=0 master`
WORK_DIR=`mktemp -d`
SCRIPT_PATH="$DIR/scripts/pg_dbo_timestamp--${LAST_VERSION:1}--$NEW_VERSION.sql"

# check temp dir creating
if [[ ! "$WORK_DIR" || ! -d "$WORK_DIR" ]]; then
  echo "Could not create temp dir"
  exit 1
fi

# write warning to first line of file
echo '\echo Use "UPDATE EXTENSION pg_dbo_timestamp TO $NEW_VERSION" to load this file. \quit' > $SCRIPT_PATH

(cd $WORK_DIR
# load and unzip pgCodeKeeper cli version
wget "https://github.com/pgcodekeeper/pgcodekeeper/releases/download/v4.3.1/pgCodeKeeper-cli-4.3.1.zip" &> /dev/null
unzip -o pgCodeKeeper-cli-*.zip -d pgcodekeeper > /dev/null
# clone last tag
git clone $DIR --shared --branch $LAST_VERSION --single-branch  &> /dev/null
# generate diff
./pgcodekeeper/pgcodekeeper-cli.sh -F $DIR/DATABASE/ pg_dbo_timestamp/DATABASE >> $SCRIPT_PATH
)

# remove first search path from script
sed -i "s/SET search_path = public, pg_catalog;//" $SCRIPT_PATH

# replace search path in functions
sed -i "s/SET search_path TO public, pg_catalog/SET search_path TO @extschema@, pg_catalog/" $SCRIPT_PATH

#remove temp dir
rm -rf "$WORK_DIR"