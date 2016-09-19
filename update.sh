#!/bin/bash

# ./update.sh
# This is the Cloudrexx update script
# Updates your workingcopy and reloads the DB if necessary
# This script assumes to be in a subfolder of the contrexx
# installation which you'd like to update

UPDATE_GIT=0
RELOAD_DATABASE=0
RESET_TYPE=
CLEAN=0

CX_PATH=""
SUPPLIED_PATH=""
INDEX_FILE=""
CONFIG_PATH=""
DB_DUMP_STRUCTURE=""
DB_DUMP_DATA=""
CX_VHOST=""
DB_USER=""
DB_PASS=""
DB_NAME=""
DB_HOST=""
DB_SESSION_FILE=""

# Set lang to german
LANG="de"
MYSQL_PW_WARNING="Warning: Using a password on the command line interface can be insecure."

for i in "$@"
do
case $i in
    -g|--git-only)
    UPDATE_GIT=1
    shift # past argument=value
    ;;
    -r|--reload)
    RELOAD_DATABASE=1
    shift # past argument=value
    ;;
    --reset)
    RESET=1
    shift # past argument=value
    ;;
    -fc|--force-clean)
    CLEAN=1
    shift # past argument=value
    ;;
    -h|--help)
    echo "This Script will update your working copy including your git repository and database"
    echo "(-g | --git) update git repository only"
    echo "(-r | --reload) reload database only"
    echo "(--reset) reload repository and database"
    echo "(-fc|--force-clean) must be used with --reset: force it to clean repository and database"
    echo "by default, both git and database will be updated"
    exit
    shift # past argument=value
    ;;
    *)
    SUPPLIED_PATH=$i
    ;;
esac
done

function createDatabase() {
    # Reloads the database of the current working copy
    # and sets the language according to your selection

    # fetch current domainUrl
    CX_VHOST=`grep -E "CONFIG\['domainUrl'\]" $CONFIG_FILE | sed -e "s/^.*CONFIG\['[a-z]\+'\]\s*=\s*\('\|\"\)\(.*\)\1\s*;.*$/\2/gi"`
    echo -e "\tUpdating DB $DB_NAME, please wait..."
    backupCxSessions
    dropDb
    loadDbStructure
    fetchDbTables
    disableDbKeys
    loadDbData
    loadCxSessions
    enableDbKeys
    setDatabaseLanguage

# TODO: properly implement dropping of MultiSite dbs
    #dropMultiSiteDbs

    # done
    echo -e "\n\tDatabase $DB_NAME reloaded and default language set to $LANG"
}

function backupCxSessions() {
    # backup sessions
    echo -en "\t- Backup Cloudrexx user sessions..."
    DB_SESSION_FILE="$(mktemp)"
    (mysqldump --host=$DB_HOST --user=$DB_USER -p$DB_PASS $DB_NAME contrexx_sessions > $DB_SESSION_FILE) 2>&1 | grep -vF "$MYSQL_PW_WARNING"
}

function dropDb() {
    # drop db
    echo -ne '\n\t- Drop current DB...'
    (mysql --host=$DB_HOST --user=$DB_USER -p$DB_PASS -A -e "DROP DATABASE $DB_NAME") 2>&1 | grep -vF "$MYSQL_PW_WARNING"
}

function loadDbStructure() {
    # load db structure
    echo -ne '\n\t- Load new DB structure...'
    # DROP all tables with syntax cloudrexx_NR.
    (mysql --host=$DB_HOST --user=$DB_USER -p$DB_PASS -A -e "CREATE DATABASE $DB_NAME COLLATE utf8_unicode_ci") 2>&1 | grep -vF "$MYSQL_PW_WARNING"
    (mysql --host=$DB_HOST --user=$DB_USER -p$DB_PASS -A $DB_NAME < $DB_DUMP_STRUCTURE) 2>&1 | grep -vF "$MYSQL_PW_WARNING"
}

function fetchDbTables() {
    # get list of db tables
    DB_TABLES="$((mysql --host=$DB_HOST --user=$DB_USER -p$DB_PASS --database $DB_NAME -e 'SHOW TABLES' -ss) 2>/dev/null)"
}

function loadDbData() {
    # load db data
    echo -ne '\n\t- Load new DB data...'
    (sed -e "s/pkg.contrexxlabs.com/$CX_VHOST/g" $DB_DUMP_DATA | mysql --host=$DB_HOST --user=$DB_USER -p$DB_PASS --default-character-set=utf8 $DB_NAME) 2>&1 | grep -vF "$MYSQL_PW_WARNING"
}

function loadCxSessions() {
    # load sessions
    echo -ne "\n\t- Load Cloudrexx user sessions backup..."
    (mysql --host=$DB_HOST --user=$DB_USER -p$DB_PASS -A --database $DB_NAME < $DB_SESSION_FILE) 2>&1 | grep -vF "$MYSQL_PW_WARNING"
    rm $DB_SESSION_FILE
}

function disableDbKeys() {
    # disable keys
    echo -ne '\n\t- Disable foreign key checks...'
    for TABLE in $DB_TABLES; do
        (mysql --host=$DB_HOST --user=$DB_USER -p$DB_PASS --database $DB_NAME -e "ALTER TABLE $TABLE DISABLE KEYS") 2>&1 | grep -vF "$MYSQL_PW_WARNING"
    done
}

function enableDbKeys() {
    # reenable keys
    echo -ne '\n\t- Reenable foreign key checks...'
    for TABLE in $DB_TABLES; do
        (mysql --host=$DB_HOST --user=$DB_USER -p$DB_PASS --database $DB_NAME -e "ALTER TABLE $TABLE ENABLE KEYS") 2>&1 | grep -vF "$MYSQL_PW_WARNING"
    done
}

function getDatabaseLogin() {
    DB_USER=`grep -E "DBCONFIG\['user'\]" $CONFIG_FILE | sed -e "s/^.*DBCONFIG\['[a-z]\+'\]\s*=\s*\('\|\"\)\(.*\)\1\s*;.*$/\2/g"`
    DB_PASS=`grep -E "DBCONFIG\['password'\]" $CONFIG_FILE | sed -e "s/^.*DBCONFIG\['[a-z]\+'\]\s*=\s*\('\|\"\)\(.*\)\1\s*;.*$/\2/g"`
    DB_NAME=`grep -E "DBCONFIG\['database'\]" $CONFIG_FILE | sed -e "s/^.*DBCONFIG\['[a-z]\+'\]\s*=\s*\('\|\"\)\(.*\)\1\s*;.*$/\2/g"`
    DB_HOST=`grep -E "DBCONFIG\['host'\]" $CONFIG_FILE | sed -e "s/^.*DBCONFIG\['[a-z]\+'\]\s*=\s*\('\|\"\)\(.*\)\1\s*;.*$/\2/g"`
}

function setDatabaseLanguage () {
    echo -ne "\n\t- Set Cloudrexx system language to $LANG..."
    (mysql --host=$DB_HOST --user=$DB_USER -p$DB_PASS --database $DB_NAME -e "UPDATE contrexx_languages SET is_default = 'false'") 2>&1 | grep -vF "$MYSQL_PW_WARNING"
    (mysql --host=$DB_HOST --user=$DB_USER -p$DB_PASS --database $DB_NAME -e "UPDATE contrexx_languages SET is_default = 'true' WHERE lang = '$LANG'") 2>&1 | grep -vF "$MYSQL_PW_WARNING"
    (mysql --host=$DB_HOST --user=$DB_USER -p$DB_PASS --database $DB_NAME -e "UPDATE contrexx_languages SET fallback = ''") 2>&1 | grep -vF "$MYSQL_PW_WARNING"
    (mysql --host=$DB_HOST --user=$DB_USER -p$DB_PASS --database $DB_NAME -e "UPDATE contrexx_languages SET fallback = NULL WHERE lang = '$LANG'") 2>&1 | grep -vF "$MYSQL_PW_WARNING"
}

function dropMultiSiteDbs() {
    mysql --host=$DB_HOST --user=$DB_USER -p$DB_PASS -e 'show databases' | grep -e "^cloudrexx_[1-9]*$" | xargs -I "@@" mysql --host=$DB_HOST --user=$DB_USER -p$DB_PASS -e "DROP database \`@@\`"
}

function detectCxInstallation() {
    # set path to Cloudrexx installation
    if [[ -z "$SUPPLIED_PATH" ]]; then
        SUPPLIED_PATH=$(pwd)
    fi

    if [[ "$SUPPLIED_PATH" =~ ^/ ]]; then
        CX_PATH=$SUPPLIED_PATH;
    else
        CX_PATH=$(pwd)/$SUPPLIED_PATH;
    fi

    if [[ "$CX_PATH" =~ /$ ]]; then
        CX_PATH=${CX_PATH%/};
    fi

    INDEX_FILE=$CX_PATH/index.php
    CONFIG_PATH=$CX_PATH/config
    DB_DUMP_STRUCTURE=$CX_PATH/installer/data/contrexx_dump_structure.sql
    DB_DUMP_DATA=$CX_PATH/installer/data/contrexx_dump_data.sql
    CONFIG_FILE=$CX_PATH/config/configuration.php

    # check if path actually points to a contrexx installation
    if [[ ! -e $INDEX_FILE ]] || [[ ! -e $CONFIG_PATH ]]; then
        echo "ERROR: This is not a Cloudrexx installation"
        exit 0
    fi

    echo "Going to update Cloudrexx installation at $CX_PATH"

    # move into directory of cx installation
    cd $CX_PATH
}

detectCxInstallation

if [[ $RESET = 1 ]]; then
    if [[ $CLEAN != 1 ]]; then
        echo "Do you only want to reset (will not delete untracked files) or also clean (untracked files will be gone forever) the installation? Type enter for reset or c for clean?"
        read RESET_TYPE
    fi
    getDatabaseLogin
    git reset --hard
    if [[ $RESET_TYPE = "c" ]]; then
        git clean -d -f -q -X
    fi
    createDatabase
    echo "Reset Cloudrexx installation"
    exit
fi

if [[ $RELOAD_DATABASE = 1 ]]; then
    getDatabaseLogin
    createDatabase
    exit
fi

# if no specific update option is set, we update everything (this is the default behaviour)
if [[ $UPDATE_GIT == 0 ]]; then
    UPDATE_GIT=1
    UPDATE_DATABASE=1
fi

if [[ $UPDATE_DATABASE = 1 ]]; then
    # Cache MD5 of old SQL dump files
    STRUCTMD5=`/usr/bin/md5sum $DB_DUMP_STRUCTURE`
    DATAMD5=`/usr/bin/md5sum $DB_DUMP_DATA`
fi

if [[ $UPDATE_GIT = 1 ]]; then
    # Update git repository
    git pull
fi

if [[ $UPDATE_DATABASE = 1 ]]; then
    # Create MD5 of new SQL dump files
    STRUCTMD5NEW=`/usr/bin/md5sum $DB_DUMP_STRUCTURE`
    DATAMD5NEW=`/usr/bin/md5sum $DB_DUMP_DATA`

    # Check for changes on SQL dump files and update DB if necessary
    if [[ $STRUCTMD5NEW != $STRUCTMD5 || $DATAMD5NEW != $DATAMD5 ]]; then
            getDatabaseLogin
            createDatabase
    else
        echo "DB Reload is not necessary"
    fi
fi
