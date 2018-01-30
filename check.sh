#!/bin/bash

# ./check.sh -f
# This is the Cloudrexx check script
# It checks if the operating system passes the requirements for Cloudrexx, if not, we try to help the user
# install the missing component

# if force fix is true, we try to install the missing components without asking the user
FORCE_FIX=0
SHOW_HELLO_MESSAGE=1
for i in "$@"
do
case $i in
    -f|--force)
    FORCE_FIX=1
    shift # past argument=value
    ;;
    -nhm|--no-hello-message)
    SHOW_HELLO_MESSAGE=0
    shift # past argument=value
    ;;
    -h|--help)
    echo "This scripts checks the system requirements for Cloudrexx and tries to fix them"
    echo "(-f|--force) force installation of missing components and do not ask for it"
    echo "(-nhm|--no-hello-message) do not show hello message at the beginning of the script"
    exit
    shift # past argument=value
    ;;
    *)# unknown option
    ;;
esac
done

if [[ $SHOW_HELLO_MESSAGE == 1 ]]; then
    echo -e "\033[1mWelcome to Cloudrexx Development Environment check\033[0m"
    echo "This script will check if everything needed for Cloudrexx coding is available"
    echo "on the current system."
    echo ""
    echo -n "Press CTRL+c to quit, press ENTER to proceed: "
    read -r
fi
# the required versions of php and mysql can be changed here. Please use syntak [1-9].[1-9].[1-9]
REQUIRED_PHP_VERSION="5.4.0"
REQUIRED_MYSQL_VERSION="5.0.0"


# outputs a message that a component is not installed
# first parameter must be the name component which is not installed
function outputNotInstalledMessage () {
    echo "$1 is not installed"
    echo "1 - Install and configure $1 (recommended)"
    echo "Enter - Ignore error and continue"
}

function writeReport () {
    REPORT="$REPORT \n$1: $2"
}

function checkVersion () {
    writeReport "$3" "installed"
    writeReport "$3 Version" $1
    if [[ ${1//.} < ${2//.} ]]; then
       # we will never install a second version of a component, because this often causes problems
       writeReport "ERROR" "You need to install at least $3 $2 to install Cloudrexx"
       exit
    fi
}

function checkApache () {
    echo "Checking apache..."
    type apache2 >/dev/null 2>&1 && APACHE_INSTALLED=1 || APACHE_INSTALLED=0
    if [[ $APACHE_INSTALLED != 1 ]]; then
        # if force fix is true, we save the information that we want to install apache, otherwise we ask the user if we should install it
        [[ $FORCE_FIX == 1 ]] && INSTALL_APACHE=1 || { outputNotInstalledMessage "Apache"; read INSTALL_APACHE; }
    else
       writeReport "APACHE" "installed"
       checkFolder
    fi
    # if apache is not installed, but we tried to install it, we inform the user, that the installation failed
    [[ $INSTALL_APACHE = 1 && $1 == 1 ]] && { writeReport "APACHE" "could not be installed, please do it manually"; exit; }
    [[ $INSTALL_APACHE == 1 ]] && installApache
}

function installApache () {
    echo "Installing Apache2..."
    sudo apt-get update
    sudo apt-get install apache2
    INSTALL_APACHE=0
    checkApache 1
}

function checkFolder () {
    APACHE_ROOT=$(apache2ctl -S | grep "DocumentRoot" | cut -d "\"" -f 2)
    if [[ ${PWD##$APACHE_ROOT} == $PWD ]]; then
        writeReport "NOTE" "Your installing folder is not inside apache root. You need to create a vhost that it works"
    fi
}

function checkPHP () {
    type php >/dev/null 2>&1 && PHP_INSTALLED=1 || PHP_INSTALLED=0
    echo "Checking php..."
    if [[ $PHP_INSTALLED != 1 ]]; then
        # if force fix is true, we save the information that we want to install php, otherwise we ask the user if we should install it
        [[ $FORCE_FIX == 1 ]] && INSTALL_PHP=1 || { outputNotInstalledMessage "PHP"; read INSTALL_PHP; }
    else
        PHP_VERSION=$(php -r \@phpinfo\(\)\; | grep 'PHP Version' -m 1 | grep -o [[:digit:]]\.[[:digit:]]\.[[:digit:]] -m 1)
        checkVersion $PHP_VERSION $REQUIRED_PHP_VERSION "PHP"
        checkPDO
        checkPHPModule "intl"
    fi
    # if PHP is not installed, but we tried to install it, we inform the user, that the installation failed
    [[ $INSTALL_PHP = 1 && $1 == 1 ]] && { writeReport "PHP" "could not be installed, please do it manually"; exit; }
    [[ $INSTALL_PHP == 1 ]] && installPHP
}

function installPHP () {
    echo "Installing PHP 5.6..."
    # add php repo, because since ubuntu 16.4 php 5.6 is no longer standard
    sudo add-apt-repository ppa:ondrej/php
    sudo apt-get update
    sudo apt-get install php5.6 libapache2-mod-php5.6 php5.6-mcrypt
    INSTALL_PHP=0
    checkPHP 1
}

function checkMySQL () {
    type mysql >/dev/null 2>&1 && MYSQL_INSTALLED=1 || MYSQL_INSTALLED=0
    echo "Checking mysql..."
    if [[ $MYSQL_INSTALLED != 1 ]]; then
        # if force fix is true, we save the information that we want to install mysql, otherwise we ask the user if we should install it
        [[ $FORCE_FIX == 1 ]] && INSTALL_MYSQL=1 || { outputNotInstalledMessage "MYSQL"; read INSTALL_MYSQL; }
    else
        MYSQL_VERSION=$(apt-cache show mysql-server | grep -o [[:digit:]]\.[[:digit:]]\.[[:digit:]][[:digit:]] -m 1)
        checkVersion $MYSQL_VERSION $REQUIRED_MYSQL_VERSION "MySQL"
    fi
    # if MySQL is not installed, but we tried to install it, we inform the user, that the installation failed
    [[ $INSTALL_MYSQL == 1 && $1 == 1 ]] && { writeReport "MySQL" "could not be installed, please do it manually"; exit; }
    [[ $INSTALL_MYSQL == 1 ]] && installMySQL
}

function installMySQL () {
    echo "Installing MySQL..."
    sudo apt-get update
    sudo apt-get install mysql-server
    installPHPModule mysql
    sudo mysql_install_db
    sudo /usr/bin/mysql_secure_installation
    INSTALL_MYSQL=0
    checkMySQL 1
}

function checkPDO () {
    if [[ $(php -m | grep "PDO") != "" ]]; then
        writeReport "PDO" "installed"
     else
        # installing pdo is not that easy. it is standard with PHP and if it was deleted by the user, we can not install
        # it for him that easy. This case should not exist very often
        writeReport "PDO" "not installed"
        writeReport "ERROR" "We can not install PDO for you, you need to do it manually"
        exit
    fi
}

# param $1: the name of the php module without prefix 'phpX.Y-' (e.g for php5.6-intl moduleName is intl)
# param $2: should be 1 if the module was installed otherwise 0
function checkPHPModule () {
    echo "Checking $1"
    [[ $(php -m | grep "$1") != "" ]] && MODULE_INSTALLED=1 || MODULE_INSTALLED=0
    if [[ $MODULE_INSTALLED != 1 ]]; then
        echo "Note" "$1 is not installed"
        # if force fix is true, we save the information that we want to install module, otherwise we ask the user if we should install it
        [[ $FORCE_FIX == 1 ]] && INSTALL_MODULE=1 || { outputNotInstalledMessage $1; read INSTALL_MODULE; }
        else
        echo "$1" "installed"
    fi
    # if module is not installed, but we tried to install it, we inform the user, that the installation failed
    [[ $INSTALL_MODULE == 1 && $2 == 1 ]] && writeReport "$1" "could not be installed, please do it manually";
    [[ $INSTALL_MODULE == 1 && $2 != 1 ]] && installPHPModule $1
}

function installPHPModule () {
    echo "Installing $1..."
    sudo apt-get update
    sudo apt-get install php$(php -r \@phpinfo\(\)\; | grep 'PHP Version' -m 1 | grep -om1 [[:digit:]]\.[[:digit:]] | head -1)-$1
    service apache2 restart
    INSTALL_MODULE=0
    checkPHPModule $1 1
}

function checkPostfix () {
    type postfix >/dev/null 2>&1 && POSTFIX_INSTALLED=1 || POSTFIX_INSTALLED=0
    echo "Checking postfix..."
    if [[ $POSTFIX_INSTALLED != 1 ]]; then
        # if force fix is true, we save the information that we want to install postfix, otherwise we ask the user if we should install it
        [[ $FORCE_FIX == 1 ]] && INSTALL_POSTFIX=1 || { outputNotInstalledMessage "POSTFIX"; read INSTALL_POSTFIX; }
    else
       writeReport "POSTFIX" "installed (optional)"
    fi
    # if Postfix is not installed, but we tried to install it, we inform the user, that the installation failed
    # we do not exit because apc is optional
    [[ $INSTALL_POSTFIX == 1 && $1 == 1 ]] && writeReport "Postfix" "could not be installed, please do it manually";
    [[ $INSTALL_POSTFIX == 1 && $1 != 1 ]] && installPostfix
}

function installPostfix () {
    echo "Installing postfix..."
    sudo apt-get update
    sudo apt-get install postfix
    INSTALL_POSTFIX=0
    checkPostfix 1
}

### Get information what is installed and what not
echo "Getting system information..."
# REPORT is used to save the information of the components, so we can output them all together - this is more user-friendly
REPORT="\033[1m----------------------------------------------------"
checkApache
checkPHP
checkMySQL
checkPostfix
writeReport "NOTE" "We didn't check if apache and mysql are running. Please check this by your own, otherwise the installation won't work"
writeReport "\n----------------------------------------------------" "\033[0m"
echo ""
echo "Check finished. Got the following to report:"
echo -e $REPORT

