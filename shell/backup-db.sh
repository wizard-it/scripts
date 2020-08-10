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
PSQL=$(whereis psql | awk '{print $2}')
PGDUMP=$(whereis pg_dump | awk '{print $2}')
TAR=$(whereis tar | awk '{print $2}')
# Default params
HOST=$(hostname)
TMP="/tmp"
DEBUG="NO"
ARC_NAME="fsbackup"


#######################
### Functions block ###
#######################

function printHelp() {
echo "
backup-database, version: $VERSION
(c) Kornilov Alexander, 2020
Usage:
-t|--type               - type of database location: mysql|mariadb|postgresql|file
-h|--db-host            - database hostname or ip address for non-file types
-P|--port               - database port number for non-file types (default: 3306|5432)
-u|--db-user            - database username for non-file types
-p|--db-password        - database password for non-file types
-d|--db-name            - database name for non-file types
-s|--source             - location of file data for file type
-o|--output             - destination of backup
-n|--name               - name of backup archive for file type (default: fsbackup)
-T|--temp               - temp dir for backup files (default: /tmp)
--help                  - print this help message
--debug                 - print result information and exit

Examples:
# Make backup of mysql database:
backup-db -t mysql --db-host localhost --db-name Syslog --db-user rsyslog --db-password P@ssw0rd -o /mnt/storage1 
# Make backup of files:
backup-db -t file -s /var/lib/mysql -o /mnt/storage1 -n my-file-backup


"
exit 0
}

function printDebug() {
    printf "%-20s : %-25s\n" "Database host" "$DB_HOST"
    printf "%-20s : %-25s\n" "Database port" "$DB_PORT"
    printf "%-20s : %-25s\n" "Database name" "$DB_NAME"
    printf "%-20s : %-25s\n" "Database user" "$DB_USER"
    printf "%-20s : %-25s\n" "Database password" "$DB_PASS"
    printf "%-20s : %-25s\n" "Type of backup" "$TYPE"
    printf "%-20s : %-25s\n" "Source" "$SRC"
    printf "%-20s : %-25s\n" "Destination" "$DST"
    printf "%-20s : %-25s\n" "Archive name" "$ARC_NAME"
    printf "%-20s : %-25s\n" "Temp directory" "$TMP"
    exit 0
}

function printError() {
    case "$1" in
        "a1")
            echo "Archive name is empty. Use --name to provide it. Using default fsbackup."
            ;;
        "a2")
            echo "Can't find TAR! Please check tar installation. Aborting..."
            ;;
        "b1")
            echo "Backup type is unknown. Use --type to provide it. Use --help for examples. Aborting..."
            ;;
        "b3")
            echo "Syntax error: [-t|--type] mysql|mariadb|file"
            ;;
        "b4")
            echo "Syntax error! Please, use '--help' to show usage examples."
            ;;
        "m1")
            echo "Can't find MYSQL! Please check mysql/mariadb pkg installation. Aborting..."
            ;;
        "m2")
            echo "Can't find MYSQLSHOW! Please check mysql/mariadb pkg installation. Aborting..."
            ;;
        "m3")
            echo "Can't find MYSQLDUMP! Please check mysql/mariadb pkg installation. Aborting..."
            ;;
        "m4")
            echo "Can't connect to server "$DB_HOST" ! Please, check connection details. Aborting..."
            ;;
        "m5")
            echo "Can't connect to server "$DB_HOST" ! WARNING: You have tried to connect to local server! Aborting..."
            ;;
        "m6")
            echo "Access denied for "$DB_USER" ! Please, check connection details. Aborting..."
            ;;
        "m7")
            echo "Database "$DB_NAME" does not exist! Please, check connection details. Aborting..."
            ;;
        "m8")
            echo "This host "$HOST" is not allowed to connect to SQL server "$DB_HOST"! Please, check permissons. Aborting..."
            ;;
        "p1")
            echo "Can't find PSQL! Please check postgresql pkg installation. Aborting..."
            ;;
        "p2")
            echo "Can't find PGDUMP! Please check postgresql pkg installation. Aborting..."
            ;;
        "p3")
            echo "Can't connect to server "$DB_HOST" ! Please, check connection details. Aborting..."
            ;;
        "p4")
            echo "Access denied for "$DB_USER" ! Please, check connection details. Aborting..."
            ;;
        "p5")
            echo "Cant read database "$DB_NAME" ! Please, check connection details. Aborting..."
            ;;
        "p6")
            echo "Database "$DB_NAME" does not exist! Please, check connection details. Aborting..."
            ;;
        "t1")
            echo "TMP dir "$TMP" does not exist! Trying to create..."
            ;;
        "t2")
            echo "Can't create or read TMP dir! Check folder "$TMP" permissons. Aborting..."
            ;;
        "t3")
            echo "TMP dir is not writable. Check folder "$TMP" permissons. Aborting...";
            ;;
        "t4")
            echo "Temp dir is empty. Use --temp to provide it. Using default /tmp."
            ;;
        "s1")
            echo "Source dir "$SRC" does not exist! Aborting..."
            ;;
        "s2")
            echo "Source dir is not readable. Check folder "$SRC" permissons. Aborting..."
            ;;
        "s3")
            echo "Source dir is empty. Use --source to provide it. Aborting..."
            ;;
        "d1")
            echo "Destination dir "$DST" does not exist! Trying to create..."
            ;;
        "d2")
            echo "Can't create or read destination dir. Check folder "$DST" permissons. Aborting..."
            ;;
        "d3")
            echo "Destination dir is not writable. Check folder "$DST" permissons. Aborting..."
            ;;
        "d4")
            echo "Destination dir is empty. Use --output to provide it. Aborting..."
            ;;
        "c1")
            echo "Database user is empty. Use --db-user to provide it. Aborting..."
            ;;
        "c2")
            echo "Database password is empty. It is not secure! Use --db-password to provide it. Aborting..."
            ;;
        "c3")
            echo "Database host is empty. Use --db-host to provide it. Aborting..."
            ;;
        "c4")
            echo "Database name is empty. Use --db-name to provide it. Aborting..."
            ;;
        "c5")
            echo "Database port is empty. Use --db-port to provide it. Using 3306 as default."
            ;;
        "c6")
            echo "Database port is empty. Use --db-port to provide it. Using 5432 as default."
            ;;
        "w1")
            echo "[WARN] Creating dump problem..."
            ;;
        "w2")
            echo "[WARN] Creating archive problem..."
            ;;
        "w3")
            echo "[WARN] Coping file problem..."
            ;;
        *)
            echo "Unknown error."
    esac
}

function checkTmp() {
    echo "$TIMESTAMP : Checking temp folder..."
    if [ -z "$TMP" ]; then TMP="/tmp"; fi
    if [ ! -d "$TMP" ]; then
        printError t1
        mkdir -p $TMP
        if [ ! $? -eq 0 ]; then printError t2; exit 1; fi
    fi
    if [ ! -w "$TMP" ]; then printError t3; exit 1; fi
}

function checkSource() {
    echo "$TIMESTAMP : Checking source folder..."
    if [ ! -d "$SRC" ]; then printError s1; exit 1; fi
    if [ ! -r "$SRC" ]; then printError s2; exit 1; fi
}

function checkDestination() {
    echo "$TIMESTAMP : Checking destination folder..."
    if [ ! -d "$DST" ]; then
        printError d1
        mkdir -p $DST
        if [ ! $? -eq 0 ]; then printError d2; exit 1; fi
    fi
    if [ ! -w "$DST" ]; then printError d3; exit 1; fi
}

function checkMysql {
    echo "$TIMESTAMP : Checking mysql db..."
    if [ -z "$MYSQL" ]; then printError m1; exit 1; fi
    if [ -z "$MYSQLSHOW" ]; then echo printError m2; exit 1; fi
    if [ -z "$MYSQLDUMP" ]; then echo printError m3; exit 1; fi
    echo "Checking database $DB_NAME ..."
    DBCHECK=$("${MYSQLSHOW}" -u"${DB_USER}" -p"${DB_PASS}" -h "${DB_HOST}" -P "${DB_PORT}" "${DB_NAME}" 2>&1)
    if [[ $DBCHECK == *"Database: ${DB_NAME}"* ]]; then
        echo "Checked!"
    else
        if [[ $DBCHECK == *"Unknown MySQL server host"* ]]; then printError m4; exit 1; fi
        if [[ $DBCHECK == *"connect to local MySQL server"* ]]; then printError m5; exit 1; fi
        if [[ $DBCHECK == *"Access denied for user"* ]]; then printError m6; exit 1; fi
        if [[ $DBCHECK == *"is not allowed to connect"* ]]; then printError m8; exit 1; fi
        if [[ $DBCHECK == *"Unknown database"* ]]; then printError m7; exit 1; fi
    fi
}

function checkPostgresql {
    echo "$TIMESTAMP : Checking postgresql db..."
    if [ -z "$PSQL" ]; then printError p1; exit 1; fi
    if [ -z "$PGDUMP" ]; then echo printError p2; exit 1; fi
    echo "Checking database $DB_NAME ..."
    DBCHECK=$(PGPASSWORD="$DB_PASS" "${PSQL}" -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'" 2>&1)
    if [[ $DBCHECK == *"could not connect to server"* ]]; then printError p3; exit 1; fi
    if [[ $DBCHECK == *"password authentication failed"* ]]; then printError p4; exit 1; fi
    if [[ $DBCHECK == *"(0 rows)"* ]]; then printError p5; exit 1; fi
    if [[ $DBCHECK == *"does not exist"* ]]; then printError p6; exit 1; fi
    echo "Checked!"
}

function checkParam() {
    case "$TYPE" in
        "mysql"|"mariadb")
            if [ -z "$DB_USER" ]; then printError c1; exit 1; fi
            if [ -z "$DB_PASS" ]; then printError c2; exit 1; fi
            if [ -z "$DB_HOST" ]; then printError c3; exit 1; fi
            if [ -z "$DB_NAME" ]; then printError c4; exit 1; fi
            if [ -z "$DB_PORT" ]; then printError c5; fi
            if [ -z "$DST" ]; then printError d4; exit 1; fi
            if [ -z "$TMP" ]; then printError t4; fi
            ;;
        "postgresql")
            if [ -z "$DB_USER" ]; then printError c1; exit 1; fi
            if [ -z "$DB_PASS" ]; then printError c2; exit 1; fi
            if [ -z "$DB_HOST" ]; then printError c3; exit 1; fi
            if [ -z "$DB_NAME" ]; then printError c4; exit 1; fi
            if [ -z "$DB_PORT" ]; then printError c6; fi
            if [ -z "$DST" ]; then printError d4; exit 1; fi
            if [ -z "$TMP" ]; then printError t4; fi
            ;;
        "file")
            if [ -z "$SRC" ]; then printError s3; exit 1; fi
            if [ -z "$DST" ]; then printError d4; exit 1; fi
            if [ -z "$TMP" ]; then printError t4; fi
            if [ -z "$ARC_NAME" ]; then printError a1; fi
            ;;
        *)
            printError b1
            exit 1
            ;;
    esac
}

function backupMysql() {
    echo "$TIMESTAMP : Backuping mysql db..."
    if [ -z "$TAR" ]; then printError a2; exit 1; fi
    if [ -z "$TMP" ]; then TMP="/tmp"; fi
    if [ -z "$DB_PORT" ]; then DB_PORT="3306"; fi
# Create dump in tmp folder
    $MYSQLDUMP --column-statistics=0 -u"$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" "$DB_NAME" > "$TMP"/db-"$DB_NAME"-"$TIMESTAMP".sql
    if [ ! $? -eq 0 ]; then printError w1; fi
# Coping and archiving data
    $TAR -czf "$TMP"/db-"$DB_NAME"-"$TIMESTAMP".tar.gz -C "$TMP" db-"$DB_NAME"-"$TIMESTAMP".sql
    if [ ! $? -eq 0 ]; then printError w2; fi
    cp "$TMP"/db-"$DB_NAME"-"$TIMESTAMP".tar.gz "$DST"/db-"$DB_NAME"-"$TIMESTAMP".tar.gz
    if [ ! $? -eq 0 ]; then printError w3; fi
}

function backupPostgresql() {
    echo "$TIMESTAMP : Backuping postgresql db..."
    if [ -z "$TAR" ]; then printError a2; exit 1; fi
    if [ -z "$TMP" ]; then TMP="/tmp"; fi
    if [ -z "$DB_PORT" ]; then DB_PORT="5432"; fi
# Create dump in tmp folder
    PGPASSWORD="$DB_PASS" $PGDUMP -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME" > "$TMP"/db-"$DB_NAME"-"$TIMESTAMP".sql
    if [ ! $? -eq 0 ]; then printError w1; fi
# Coping and archiving data
    $TAR -czf "$TMP"/db-"$DB_NAME"-"$TIMESTAMP".tar.gz -C "$TMP" db-"$DB_NAME"-"$TIMESTAMP".sql
    if [ ! $? -eq 0 ]; then printError w2; fi
    cp "$TMP"/db-"$DB_NAME"-"$TIMESTAMP".tar.gz "$DST"/db-"$DB_NAME"-"$TIMESTAMP".tar.gz
    if [ ! $? -eq 0 ]; then printError w3; fi
}

function backupFile() {
    echo "$TIMESTAMP : Backuping files..."
    if [ -z "$TAR" ]; then printError a2; exit 1; fi
    if [ -z "$TMP" ]; then TMP="/tmp"; fi
    if [ -z "$ARC_NAME" ]; then ARC_NAME="fsbackup"; fi
# Coping and archiving data
    $TAR -czf "$TMP"/"$ARC_NAME"-"$TIMESTAMP".tar.gz -C "$SRC" .
    if [ ! $? -eq 0 ]; then printError w2; fi
    cp "$TMP"/"$ARC_NAME"-"$TIMESTAMP".tar.gz "$DST"/"$ARC_NAME"-"$TIMESTAMP".tar.gz
    if [ ! $? -eq 0 ]; then printError w3; fi
}

function cleanTmp() {
    echo "$TIMESTAMP : Cleaning temp folder..."
    case "$TYPE" in
        "mysql"|"mariadb")
            rm -rf "$TMP"/db-"$DB_NAME"-"$TIMESTAMP".sql
            rm -rf "$TMP"/db-"$DB_NAME"-"$TIMESTAMP".tar.gz
            ;;
        "postgresql")
            rm -rf "$TMP"/db-"$DB_NAME"-"$TIMESTAMP".sql
            rm -rf "$TMP"/db-"$DB_NAME"-"$TIMESTAMP".tar.gz
            ;;
        "file")
            rm -rf "$TMP"/"$ARC_NAME"-"$TIMESTAMP".tar.gz
            ;;
        *)
            ;;
    esac
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
                "postgresql")
                    TYPE="postgresql"
                    ;;
                "file")
                    TYPE="file"
                    ;;
                *)
                    printError b3
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
        "-p"|"--db-password")
            DB_PASS=$2
            shift 2
            ;;
        "-s"|"--source")
            SRC=$2
            shift 2
            ;;
        "-o"|"--output")
            DST=$2
            shift 2
            ;;
        "-n"|"--name")
            ARC_NAME=$2
            shift 2
            ;;
        "-T"|"--temp")
            TMP=$2
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
            printError b4
            exit 1
            ;;
    esac
done
# Stop for debugging
if [[ "$DEBUG" == "YES" ]]; then printDebug; fi
# Check input params
checkParam
# Check tmp folder
checkTmp
# Check destination
checkDestination
# Backuping
case "$TYPE" in
    "mysql"|"mariadb")
        checkMysql
        backupMysql
        ;;
    "postgresql")
        checkPostgresql
        backupPostgresql
        ;;
    "file")
        checkSource
        backupFile
        ;;
    *)
        ;;
esac
# Some cleaning
cleanTmp
exit 0