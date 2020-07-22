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
MYSQL=$(whereis mysql | awk '{print $2}')
MYSQLSHOW=$(whereis mysqlshow | awk '{print $2}')
MYSQLDUMP=$(whereis mysqldump | awk '{print $2}')


#######################
### Functions block ###
#######################

# The function for help messages
function printHelp() {
echo "
backup-database, version: $VERSION
(c) Kornilov Alexander, 2020
Usage:
-t|--type               - type of database location: mysql|mariadb|file
-h|--db-host            - database hostname or ip address for non-file types
-P|--port               - database port number for non-file types (default: 3306)
-u|--db-user            - database username for non-file types
-p|--db-password        - database password for non-file types
-d|--db-name            - database name for non-file types
-s|--source             - location of file data for file type
-o|--output             - destination of backup (default: /tmp)
--help                  - print this help message
--debug                 - print result information and exit

Examples:
# Make backup of mysql database:
backup-db -t mysql --db-host localhost --db-name Syslog --db-user rsyslog --db-password P@ssw0rd -o /mnt/storage1 
# Make backup of files:
backup-db -t file -s /var/lib/mysql -o /mnt/storage1


"
exit 0
}

function checkSource() {
    TARGET=$1
    if [ ! -d "$TARGET" ]; then
        echo "Source dir $TARGET does not exist! Aborting..."
        exit 1
    fi
}

function checkDestination() {
    TARGET=$1
    if [ ! -d "$TARGET" ]; then
        echo "Destination dir $TARGET does not exist! Trying to create..."
        mkdir -p $TARGET
        if [ $? -eq 1 ]; then
            echo "Can't create or read dir $TARGET! Aborting..."
            exit 1
        fi
    fi

}

function checkMysql {
    if [ $# -lt 5 ]; then
        echo "Syntax error! Please, use this function like this one: checkMysql <db name> <db host> <db port> <db user> <db password>"
        exit 1
    fi
    if [ -z "${MYSQL}" ]; then
        echo "Can't find MYSQL! Please check mysql/mariadb pkg installation. Aborting..."
        exit 1
    fi
    if [ -z "${MYSQLSHOW}" ]; then
        echo "Can't find MYSQLSHOW! Please check mysql/mariadb pkg installation. Aborting..."
        exit 1
    fi
    if [ -z "${MYSQLDUMP}" ]; then
        echo "Can't find MYSQLDUMP! Please check mysql/mariadb pkg installation. Aborting..."
        exit 1
    fi
    TARGETNAME=$1
    TARGETHOST=$2
    TARGETPORT=$3
    TARGETUSER=$4
    TARGETPWD=$5

# debug string
#    echo "DB type:$DBTYPE DB name:$TARGETNAME DB host:$TARGETHOST DB port:$TARGETPORT DB user:$TARGETUSER DB password:$TARGETPWD"
    echo "Checking database $TARGETNAME ..."
    DBCHECK=$("${MYSQLSHOW}" -u"${TARGETUSER}" -p"${TARGETPWD}" -h "${TARGETHOST}" -P "${TARGETPORT}" "${TARGETNAME}" 2>&1)
    if [[ $DBCHECK == *"Database: ${TARGETNAME}"* ]]; then
        echo "Checked!"
    else
        if [[ $DBCHECK == *"Unknown MySQL server host"* ]]; then
            echo "Can't connect to server $TARGETHOST !\nPlease, check connection details. Aborting..."
            exit 1
        fi
        if [[ $DBCHECK == *"connect to local MySQL server"* ]]; then
            echo "Can't connect to server $TARGETHOST !\nWARNING: You have tried to connect to local server! Aborting..."
            exit 1
        fi
        if [[ $DBCHECK == *"Access denied for user"* ]]; then
            echo "Access denied for $TARGETUSER !\nPlease, check connection details. Aborting..."
            exit 1
        fi      
        if [[ $DBCHECK == *"Unknown database"* ]]; then
            echo "Database $TARGETNAME does not exist!\nPlease, check connection details. Aborting..."
            exit 1
        fi       
    fi
# debug string
#    echo "DBCHECK:$DB_CHECK"
}


#########################
### Main (Body) block ###
#########################

# Parsing given arguments
if [[ $# -eq 0 ]]; then printHelp; fi

while [[ $# -gt 0 ]]
do
    ARG="$1"
    case "$ARG" in
        "-t"|"--type")
            TYPE=$2
            case "$TYPE" in
                "mysql"|"mariadb")
                    TYPE="mysql"
                    ;;
                "file")
                    TYPE="file"
                    ;;
                *)
                    echo "Syntax error: [-t|--type] mysql|mariadb|file"
                    exit 1
                    ;;
            esac
            shift 2
            ;;
        "-d"|"--db-name")
            DB_NAME=$2
            shift 2
            ;;
        "-h"|"--db-host")
            DB_HOST=$2
            shift 2
            ;;
        "-P"|"--port")
            DB_PORT=$2
            shift 2
            ;;
        "-u"|"--db-user")
            DB_USER=$2
            shift 2
            ;;
        "-s"|"--source")
            SRC=$2
            shift 2
            ;;
        "-o"|"--output")
            DEST=$2
            shift 2
            ;;
        "--debug")
            DEBUG="YES"
            shift
            ;;
        "--help")
            printHelp
            ;;
        *)
            echo "Syntax error! Please, use '--help' to show usage examples."
            exit 1
            ;;
    esac
done

# Set defaults if arguments aren't presented
if ! [[ "$TMP" ]]; then TMP="/tmp"; fi
if ! [[ "$DB_NAME" ]]; then DB_NAME="zabbix"; fi
if ! [[ "$DB_HOST" ]]; then DB_HOST="localhost"; fi
if ! [[ "$DEST" ]]; then DEST=$(pwd); LOGFILE="$DEST/zbx_backup.log"; fi
if ! [[ "$ROTATION" ]]; then ROTATION=10; fi
if ! [[ "$ZBX_CATALOGS" ]]; then ZBX_CATALOGS=("/usr/lib/zabbix" "/etc/zabbix"); fi
if [[ "$USE_COMPRESSION" ]] && ! [[ $(command -v "$COMPRESS_WITH") ]]; then echo "ERROR: '$COMPRESS_WITH' utility not found."; exit 1; fi

#
# A lot of checks, trying to make this script more friendly
#

# Check '-b' option is provided
if ! [[ "$B_UTIL"  ]]; then echo "ERROR: You must provide backup utility ('-b')."; exit 1; fi

# Checking TMP and DST directories existing
if ! [[ -d "$TMP" ]]; then if ! mkdir -p $TMP; then echo "ERROR: Cannot create temp directory ($TMP)."; exit 1; fi; fi
if ! [[ -d "$DEST" ]]; then echo "ERROR: $TIMESTAMP : Destination directory doesn't exists." | tee -a "./zbx_backup.log"; exit 1; fi

# Enter the password if it equal to '-'
if  [[ "$DB_PASS" == "-" ]]
then
        read -s -p "Please, enter the password for user '$DB_USER': " DB_PASS
        echo -e "\n"
fi

# Check if username is provided
if [[ "$DB_USER" ]]
then
        if [[ "$DB_USER" =~ ^[0-9]|- ]] && ! [[ "$FORCE" ]]
        then
                echo "WARNING: Username '$DB_USER' looks wrong (starts with '-' or digit). Use '--force' if it's OK."
                exit 1
        fi
else
        echo "ERROR: You must provide username to connect to the database ('-u|--db-user')."
        exit 1
fi


if [[ "$DEBUG" == "YES" ]]
then
        function join { local IFS="$1"; shift; echo "$*"; }

        printf "%-20s : %-25s\n" "Database host" "$DB_HOST"
        printf "%-20s : %-25s\n" "Database name" "$DB_NAME"
        printf "%-20s : %-25s\n" "Database user" "$DB_USER"
        printf "%-20s : %-25s\n" "Database password" "$DB_PASS"
        printf "%-20s : %-25s\n" "Use compression" "$USE_COMPRESSION"
        printf "%-20s : %-25s\n" "Compression utility" "$COMPRESS_WITH"
        printf "%-20s : %-25s\n" "Old copies count" "$ROTATION"
        printf "%-20s : %-25s\n" "Logfile location" "$LOGFILE"
        printf "%-20s : %-25s\n" "Temp directory" "$TMP"
        printf "%-20s : %-25s\n" "Final distination" "$DEST"
        printf "%-20s : %-25s\n" "Backup utility" "$B_UTIL"
        if ! [[ "$DB_ONLY" ]]; then printf "%-20s : %-30s\n" "Zabbix catalogs" "$(join ', ' "${ZBX_CATALOGS[@]}")"; fi
        if [[ "$EXCLUDE_TABLES" ]]; then printf "%-20s : %-30s\n" "Exclude tables" "$EXCLUDE_TABLES"; fi
        exit 0
fi

exit 0
