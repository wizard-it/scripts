#!/bin/bash
# AUTHOR: Alexander Kornilov <spellbook33@gmail.com>
# MAINTAINER: Alexander Kornilov <spellbook33@gmail.com>
# Version: stable


##################
### Vars block ###
##################

# Version number
VERSION="1.0"
# Current timestamp
TIMESTAMP=$(date +%d.%m.%Y.%H%M%S)
# Applications
SED=$(whereis sed | awk '{print $2}')
GIT=$(whereis git | awk '{print $2}')
PYTHON=$(whereis python | awk '{print $2}')
# Default params
HOST=$(hostname)
TMP="/tmp"
DEBUG="NO"
PRGDIR="/opt/ansible"
ZABBIXCONVERTSCRIPT="ansible-dynamic-inventory-converter.py"
ZABBIXEXPORTSCRIPT="zabbix.py"
TMPFILE="hosts_dyn_zabbix.src"
OUTPUTFILE="hosts_dyn_zabbix"
GITSYNC="NO"



#######################
### Functions block ###
#######################

function printHelp() {
echo "
gen-zabbix-inventory, version: $VERSION
(c) Kornilov Alexander, 2020
Usage:
-g|--git               - update git src
-d|--dir               - set working(project) directory

"
exit 0
}

function generateInventoryFile {
    # Generate static inventory
    echo '' > $TMPFILE
    ./"$ZABBIXEXPORTSCRIPT" --list | ./"$ZABBIXCONVERTSCRIPT"
    # Drop a spaces from names
    $SED -e 's/^[ \t]*// ; s/[[:blank:]]*$// ; s/\s\+/_/g ; s/,$//' $TMPFILE | tee $OUTPUTFILE
    cd host_vars
    find . -name "* *" -type f -print0 | \
    while read -d $'\0' f; do
        mv -v "$f" "${f// /_}";
    done
    cd ..

}

function syncGit {
    $GIT add .
    $GIT commit -m "Auto commit $TIMESTAMP"
    $GIT push origin master
}

#########################
### Main (Body) block ###
#########################

# Parsing given arguments
while [[ $# -gt 0 ]]
do
    ARG="$1"
    case "$ARG" in
        "-d"|"--dir")
            PRGDIR=$2
            shift 2
            ;;
        "-g"|"--git")
            GITSYNC="YES"
            shift
            ;;
        "-h"|"--help")
            printHelp
            ;;
        *)
            echo "Unknown param detected, use -h param for help."
            exit 1
            ;;
    esac
done

if [ ! -d "$PRGDIR" ]; then echo "Work dir does not found or access denied!"; exit 1; fi
if [ -z "$SED" ]; then echo "SED util does not found!"; exit 1; fi
if [ -z "$GIT" ]; then echo "GIT util does not found!"; exit 1; fi
if [ ! -f "$PRGDIR/$ZABBIXCONVERTSCRIPT" ]; then echo "Zabbix convert script does not found!"; exit 1; fi
if [ ! -f "$PRGDIR/$ZABBIXEXPORTSCRIPT" ]; then echo "Zabbix export script does not found!"; exit 1; fi
if [ -z "$PYTHON" ]; then echo "PYTHON shell does not found!"; exit 1; fi

cd $PRGDIR
if [[ "$GITSYNC" == "YES" ]]; then $GIT pull; fi
generateInventoryFile
if [[ "$GITSYNC" == "YES" ]]; then syncGit; fi

