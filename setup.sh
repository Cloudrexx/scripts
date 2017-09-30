#!/bin/bash

# ./setup.sh -m -b=master
# This is the Cloudrexx setup script
# It will setup local Cloudrexx installation including config and database

# as a standard, we do not want to install multisite
SETUP_MULTISITE=0

for i in "$@"
do
case $i in
    -m|--multi-site)
    SETUP_MULTISITE=1
    shift # past argument=value
    ;;
    -b=*|--branch=*)
        GIT_BRANCH="${i#*=}"
    shift # past argument=value
    ;;
    -h|--help)
    echo "This Script will setup local cloudrexx installation including config and database"
    echo "(-m|--multi-site) setup multisite if possible with your branch"
    echo "(-b|--branch) say which branch you want to install"
    exit
    shift # past argument=value
    ;;
    *) # unknown option
    ;;
esac
done

function writeConfig () {
    sed -i "/DBCONFIG\['password'\]/c\$_DBCONFIG['password'] = '$DB_PASS'; // Database password" config/configuration.php
    sed -i "/DBCONFIG\['user'\]/c\$_DBCONFIG['user'] = '$DB_USER'; // Database password" config/configuration.php
    sed -i "/DBCONFIG\['database'\]/c\$_DBCONFIG['database'] = '$DB_NAME'; // Database password" config/configuration.php
    sed -i "/PATHCONFIG\['ascms_root'\] =/c\$_PATHCONFIG['ascms_root'] = '$APACHE_ROOT';" config/configuration.php
    sed -i "/PATHCONFIG\['ascms_root_offset'\] =/c\$_PATHCONFIG['ascms_root_offset'] = '$REWRITE_OFFSET_CONFIG';" config/configuration.php
    sed -i "/define('CONTREXX_INSTALLED'/c\define('CONTREXX_INSTALLED', true);" config/configuration.php
    sed -i "/RewriteBase/c\RewriteBase $REWRITE_BASE" .htaccess
}

function setupDatabase () {
    echo "Setting up database..."
    echo "NOTE: Please ignore the following warning: 'Warning: Using a password on the command line interface can be insecure.'"
    mysql -u$DB_ADMIN_USER -p$DB_ADMIN_PASS -e "CREATE DATABASE IF NOT EXISTS $DB_NAME COLLATE utf8_unicode_ci;"
    if [[ $DB_ADMIN_USER != $DB_USER ]]; then
        mysql -u$DB_ADMIN_USER -p$DB_ADMIN_PASS -e "GRANT ALL ON $DB_NAME.* TO $DB_USER;"
    fi
    echo "Insert structure..."
    mysql -u$DB_ADMIN_USER -p$DB_ADMIN_PASS $DB_NAME < $DB_DUMP_STRUCTURE
    echo "Insert data..."
    mysql -u$DB_ADMIN_USER -p$DB_ADMIN_PASS --default-character-set=utf8 $DB_NAME < $DB_DUMP_DATA
    echo "Please enter domain name: "
    read CX_VHOST
    # replace domainUrl from pkg with our domain url
    mysql -u$DB_ADMIN_USER -p$DB_ADMIN_PASS -e "USE $DB_NAME; UPDATE contrexx_settings SET setvalue = '$CX_VHOST' WHERE setname = 'domainUrl';"
}

function checkoutGITBranch () {
    # we need to check if branch already exists local and if so we can check it out without fetching
    if [[ $(git branch | grep "$GIT_BRANCH") != "" ]]; then
        git checkout $GIT_BRANCH
    else
        git fetch
        git checkout -b $GIT_BRANCH origin/$GIT_BRANCH || exit;
    fi
}

function checkMultiSite () {
    if [[ $SETUP_MULTISITE == 1 ]]; then
        # check if component exists in this branch, if some creates the folder on his own without the files
        # and executes the script, it will not work and destroy the installation,
        # because it will try to load files which do not exists
        if [[ -d core_modules/MultiSite ]]; then
            echo "setup multisite..."
            php _meta/setupMultiSiteFrontend.php
            mkdir websites
            chmod 664 config/*.yml core_modules/MultiSite/Data/*.txt config/settings.php tmp
            chmod 664 -R images
            chmod 775 websites config
            sed -i "/value: none/c\  value: hybrid" config/MultiSite.yml
        else
            echo "component MultiSite doesn't exists"
        fi
    fi
}

#set master as default branch
if [[ $GIT_BRANCH == "" ]]; then
    GIT_BRANCH="master"
fi
APACHE_ROOT=$(apache2ctl -S | grep "DocumentRoot" | cut -d "\"" -f 2)
REWRITE_BASE=${PWD#$APACHE_ROOT}
REWRITE_OFFSET_CONFIG=$REWRITE_BASE

USE_SAME_MYSQL_USER=0
while [[ $USE_SAME_MYSQL_USER != 1 ]]
do

echo "Please enter USERNAME which will create database: "
read DB_ADMIN_USER

echo "Please enter PASSWORD of the user which creates the database: "
read -s DB_ADMIN_PASS

if ! mysql -u $DB_ADMIN_USER -p$DB_ADMIN_PASS  -e ";" ; then
       echo "THE PASSWORD YOU ENTERED IS NOT CORRECT, PLEASE TRY AGAIN"
else
    echo "Login correct: Do you want to use $DB_ADMIN_USER to access your database?"
    echo "1 - Yes I will"
    echo "enter - no I will use another existing one"
    read USE_SAME_MYSQL_USER
    echo $USE_SAME_MYSQL_USER
fi
done

echo "Please enter NAME FOR DATABASE which will be created: "
read DB_NAME



if [[ $USE_SAME_MYSQL_USER == 1 ]]; then
    DB_USER=$DB_ADMIN_USER
    DB_PASS=$DB_ADMIN_PASS
else
    echo "Please enter USERNAME which will access database: "
    read DB_USER

    echo "Please enter PASSWORD of the user which will access the database: "
    read -s DB_PASS

fi


echo "We found $REWRITE_BASE as RewriteBase. Press enter if this is correct, otherwise type in the correct ROOT_OFFSET"
read ROOT_OFFSET

[[ $ROOT_OFFSET != "" ]] && REWRITE_BASE=$ROOT_OFFSET

checkoutGITBranch

DB_DUMP_STRUCTURE=installer/data/contrexx_dump_structure.sql
DB_DUMP_DATA=installer/data/contrexx_dump_data.sql

setupDatabase
writeConfig
checkMultiSite
