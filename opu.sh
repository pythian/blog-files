#!/bin/bash
############################################################
#
# OPatch Update v1.1
#
# Autor:                Odair Brun
# Date:                 11/04/2023
# Description:  Purpose of this script is to automate
#                               the process to upgrade the OPatch utility.
#
# Updates:
#
#       01-15-2024 Replace curl option --netrc-file option to --user
#
#############################################################

version="v1.1"

# Function to display usage information
display_usage() {
  echo "OPatch Update version ${version}"
  echo
  echo "Usage: $0 [-h][-o <ORACLE_HOME>]"
  echo "Options:"
  echo "  -o <ORACLE_HOME>    The ORACLE_HOME to update OPatch."
  echo "                       If not provided it will use ORACLE_HOME variable set."
  echo "  -h                   Display usage"
  echo
}

# Check for the -h option separately
if [[ "$1" == "-h" ]]; then
  display_usage
  exit 0
fi

# Parse command line arguments
while getopts "o:u:p:h" opt; do
  case "$opt" in
    o) ORACLE_HOME=$OPTARG;;
    h) display_usage; exit 0;;
    \?) echo "Invalid option: -$OPTARG" >&2; display_usage; exit 1;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OPATCHID=6880880

if [ -z "$ORACLE_HOME" ]; then
  # ORACLE_HOME not set
  echo "Failed. ORACLE_HOME is not set!"
  echo "Either set variable ORACLE_HOME or use option -o to inform the ORACLE_HOME."
  echo
  display_usage
  exit 1
fi

# Get the owner of the directory
opatch_owner=$(stat -c '%U' "${ORACLE_HOME}/OPatch")

# Get the current user
current_user=$(id -u -n)

# Check if the directory owner is the same as the current user
if [ "$opatch_owner" != "$current_user" ]; then
  echo "Failed. The script must be executed by the user who owns the ORACLE_HOME/OPatch directory."
  exit 1
fi

echo "OPatch Update ${version}"
date
echo
echo "[INFO] ORACLE_HOME=$ORACLE_HOME"

$ORACLE_HOME/OPatch/opatch version > $SCRIPT_DIR/current_version.out

# check current version
if grep -q "OPatch succeeded." $SCRIPT_DIR/current_version.out
then
    echo "[INFO] Checking current version ..."
        $ORACLE_HOME/OPatch/opatch lsinv > $SCRIPT_DIR/opatch_lsinv.out
    ORACLE_RELEASE=`cat $SCRIPT_DIR/opatch_lsinv.out |grep -E '(Oracle Database|Oracle Grid Infrastructure)' | awk '{print $NF}'`
    if [ -z "$ORACLE_RELEASE" ]; then
        echo "[ERROR] Oracle product or version not supported for this script."
        exit 1
    fi
    if [ $ORACLE_RELEASE == "11.2.0.4.0" ]; then
       ORACLE_RELEASE="11.2.0.0.0"
    fi
    if [ $ORACLE_RELEASE == "12.1.0.2.0" ]; then
       ORACLE_RELEASE="12.2.0.1.0"
    fi
    cat $SCRIPT_DIR/current_version.out
    CURRENT_VERSION=`cat $SCRIPT_DIR/current_version.out | grep "OPatch Version:" | awk '{print $NF}'`
else
        echo "[ERROR] Invalid ORACLE_HOME=$ORACLE_HOME"
        exit 1
fi

echo "[INFO] Searching for a new version ..."

# get platform id
plat_lang=$(cat $SCRIPT_DIR/opatch_lsinv.out |grep "ARU platform id:" | awk '{print $NF}')
plat_lang="${plat_lang}P"
url_search="https://updates.oracle.com/Orion/SimpleSearch/process_form?search_type=patch&patch_number=${OPATCHID}&plat_lang=$plat_lang"

user=`cat $SCRIPT_DIR/.netrc|grep login | awk '{print $NF}'`
password=`cat $SCRIPT_DIR/.netrc|grep password | awk '{print $NF}'`

# search for new version
curl -sS -L --location-trusted "$url_search" -o $SCRIPT_DIR/search.out --user ${user}:${password} --cookie-jar $SCRIPT_DIR/.cookie

if [ $? -ne 0 ] || [ "$(grep -q '<TITLE>Error' "$SCRIPT_DIR/search.out")" ] || [ "$(wc -c < "$SCRIPT_DIR/search.out")" -lt 5000 ]; then
  # search not succeeded
  echo "[ERROR] Search at MOS failed!"
  exit 1
fi

VERSION=`cat $SCRIPT_DIR/search.out | grep $ORACLE_RELEASE | grep OPatch | awk -F '>OPatch ' '{split($2, a, " "); print a[1]}'`
if [ -z "$VERSION" ]; then
   echo "[ERROR] Oracle version not supported for this script."
   exit 1
fi

if [ $CURRENT_VERSION == $VERSION ]; then
  # Opatch already updated
  echo "OPatch already updated, nothing to do."
  exit 1
else
  # new version available
  echo "[INFO] New version ${VERSION} is available."
  echo "[INFO] Downloading new version ... "
fi

# download new version
url_download=`cat $SCRIPT_DIR/search.out |grep https| grep $OPATCHID| grep "${ORACLE_RELEASE//./}" | sed -e "s/^.*\href[^\"]*\"//g;s/\".*$//g;s/&$//g"`
FILE_OUTPUT=`echo $url_download | awk -F '=' '{print $NF}'`

curl -sS -L --location-trusted "$url_download" -o $SCRIPT_DIR/$FILE_OUTPUT --user ${user}:${password} --cookie-jar $SCRIPT_DIR/.cookie

if [ $? -eq 0 ]; then
  # download was successull
  echo "[INFO] Download completed."
else
  echo "[ERROR] Download failed!"
  exit 1
fi

# backup current version
BACKUP_DATE=$(date "+%Y%m%d%H%M")
cp -pr $ORACLE_HOME/OPatch $SCRIPT_DIR/OPatch.OPU.$BACKUP_DATE
if [ $? -eq 0 ]; then
  # backup was successfull
  echo "[INFO] Backuping current version ... done."
  # removing current version
  rm -fr $ORACLE_HOME/OPatch/*
  if [ $? -eq 0 ]; then
        echo "[INFO] Removing the current version ... done."
  else
    # removing failed
    echo "[ERROR] Removing current version failed!"
    exit 1
  fi
else
  # backup failed
  echo "[ERROR] Backup failed!"
  exit 1
fi

# Unzip the downloaded file
cd $ORACLE_HOME/OPatch
unzip -q -o "$SCRIPT_DIR/$FILE_OUTPUT" -d ../
if [ $? -eq 0 ]; then
  # Unzip was successful
  echo "[INFO] Unzipping the new version ... done."
else
  # Unzip failed
  echo "[ERROR] Unzip failed!"
  rm -fr $ORACLE_HOME/OPatch/*
  cp -pr $SCRIPT_DIR/OPatch.OPU.$BACKUP_DATE/* $ORACLE_HOME/OPatch/
  if [ $? -eq 0 ]; then
    # rollback was successfull
    echo "[INFO] Restoring backup ... done"
    exit 0
  else
    # rollback failed
    echo "[ERROR] Restoring backup failed!"
  fi
  exit 1
fi

$ORACLE_HOME/OPatch/opatch version > $SCRIPT_DIR/opatch_version.out
# check if installation suceeded
if  grep -q "OPatch succeeded." $SCRIPT_DIR/opatch_version.out
then
    echo "[SUCCESS] OPatch upgrade completed."
    echo
    cat $SCRIPT_DIR/opatch_version.out
    # remove downloaded version
    rm -f $SCRIPT_DIR/$FILE_OUTPUT
    # remove backup
    rm -fr $SCRIPT_DIR/OPatch.OPU.$BACKUP_DATE
else
   # opatch upgdrade failed
   echo "[ERROR] OPatch update failed!"
   cat $SCRIPT_DIR/opatch_version.out
   rm -fr $ORACLE_HOME/OPatch/*
   cp -pr $SCRIPT_DIR/OPatch.OPU.$BACKUP_DATE/* $ORACLE_HOME/OPatch/
   if [ $? -eq 0 ]; then
     # rollback was successfull
     echo "[INFO] Rostoring backup ... done"
     exit 0
   else
     # rollback failed
     echo "[ERROR] Rollback failed!"
   fi
   exit 1
fi

exit 0

