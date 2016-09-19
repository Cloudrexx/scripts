#!/bin/bash

# ./init.sh -m -b=cloudrexx -r=LINK
# This is the Cloudrexx init script
# It clones the cloudrexx tool repo and then calls check.sh to see if the system requirements for cloudrexx are fulfilled
# If so it also clones the cloudrexx repo and calls setup.sh to install the database and if used the MultiSite
# as a standard, we do not want to install MultiSite
SETUP_MULTISITE=0

for i in "$@"
do
case $i in
    -m|--multi-site)
    SETUP_MULTISITE=1
    shift # past argument=value
    ;;
    -r=*|--main-repo=*)
    MAIN_REPO_URL="${i#*=}"
    shift # past argument=value
    ;;
    -b=*|--branch=*)
    GIT_BRANCH="${i#*=}"
    shift # past argument=value
    ;;
    -f|--force)
    FORCE_FIX=1
    shift # past argument=value
    ;;
    -t=*|--tools-repo=*)
    TOOLS_REPO_URL="${i#*=}"
    shift # past argument=value
    ;;
    -h|--help)
    echo "This Script will initialize and setup local cloudrexx installation including your git repository and database"
    echo "(-m|--multi-site) setup MultiSite if possible with your branch"
    echo "(-r|--main-repo) take an other git repo than github/cloudrexx/cloudrexx"
    echo "(-b|--branch) say which branch you want to install"
    echo "(-t|--tools-repo) take another repo than github/cloudrexx/tools"
    echo "(-f|--force) force installation of missing components and do not ask for it"
    exit
    shift # past argument=value
    ;;
    *) # unknown option
    ;;
esac
done

echo -e "\033[1mWelcome to Cloudrexx Development Setup.\033[0m"
echo "This wizard will ask you for database credentials and setup the development"
echo "environment in the current directory."
echo ""
echo -n "Press CTRL+c to quit, press ENTER to proceed: "
read -r

function checkGIT () {
    type git >/dev/null 2>&1 && GIT_INSTALLED=1 || GIT_INSTALLED=0
    if [[ $GIT_INSTALLED != 1 ]]; then
        if [[ $FORCE_FIX == 1 ]]; then
            INSTALL_GIT=1
        else
            echo "1 - Install and configure GIT (recommended)"
            echo "Enter - Ignore error and continue"
            read INSTALL_GIT
        fi
    fi
    # if GIT is not installed, but we tryed to install it, we inform the user, that the installation failed
    [[ $INSTALL_GIT = 1 && $1 == 1 ]] && { echo "GIT could not be installed, please do it manually"; exit; }
    [[ $INSTALL_GIT == 1 ]] && installGIT
}

function installGIT () {
    echo "Installing GIT..."
    sudo apt-get update
    sudo apt-get install git
    INSTALL_GIT=0
    checkGIT 1
}

FORCE_FIX=0

checkGIT
if [[ $MAIN_REPO_URL == "" ]]; then
    MAIN_REPO_URL="http://github.com/Cloudrexx/cloudrexx"
fi
if [[ $GIT_BRANCH == "" ]]; then
    GIT_BRANCH="master"
fi

if [[ $TOOLS_REPO_URL == "" ]]; then
    TOOLS_REPO_URL="https://github.com/Cloudrexx/dev-tools"
fi
TOOLS_REPO_FOLDER="${TOOLS_REPO_URL##*/}"

# clone tools repo || if it fails we stop the script
echo "Cloning tools repository"
git clone $TOOLS_REPO_URL $TOOLS_REPO_FOLDER || exit 1

# check system requirements
echo "Checking environment"
if [[ $FORCE_FIX != 1 ]]; then
    ./$TOOLS_REPO_FOLDER/check.sh -nhm
else
    ./$TOOLS_REPO_FOLDER/check.sh -f -nhm
fi

# clone main repo
echo "Cloning main repository"
git clone -b $GIT_BRANCH $MAIN_REPO_URL $GIT_BRANCH || exit 1
cd $GIT_BRANCH

# create _meta symlink
echo "Linking the two repositories"
ln -s ../$TOOLS_REPO_FOLDER _meta

# Create .gitignore to ignore _meta and installer/data backup dumps
printf "_meta\ninstaller/data" >> .gitignore

# setup installation
echo "Setup Cloudrexx installation"
if [[ $SETUP_MULTISITE != 1 ]]; then
    ./_meta/setup.sh -b=$GIT_BRANCH
else
    ./_meta/setup.sh --multi-site -b=$GIT_BRANCH
fi

echo ""
echo -e "\033[1mSetup finished successfully\033[0m"
echo ""
echo "Feel free to call ./_meta/update.sh to update your installation."
echo "Please note, that this might reset your database."
echo ""
echo "The Cloudrexx team wishes happy coding!"
echo ""

