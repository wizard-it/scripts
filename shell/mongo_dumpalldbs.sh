#!/bin/bash

export PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin"

# Destiny folder where backups are stored
DEST=/opt/backup/mongo

CURRDATE=$(date +"%F")

# Hostname where NoSql is running
HOSTNAME="localhost"
# User name to make backup
USER="backup"
# File where has the mysql user password
PASS="$(cat /usr/local/etc/sqlpass)"

[ ! -d $DEST ] && mkdir -p $DEST

mongodump --host localhost --out $DEST
