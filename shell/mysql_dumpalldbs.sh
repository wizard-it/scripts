#!/bin/bash

export PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin"
export HOME="/root"

# Destiny folder where backups are stored
DEST=/usr/local/backup/mysql

#CURRDATE=$(date +"%F")

# Hostname where MySQL is running
HOSTNAME="localhost"
# User name to make backup
USER="root"
# File where has the mysql user password
#PASS="$(cat /usr/local/etc/sqlpass)"

DATABASES=$(mysql -h $HOSTNAME -u $USER -e "SHOW DATABASES;" | tr -d "| " | grep -v Database)

[ ! -d $DEST ] && mkdir -p $DEST

for db in $DATABASES; do
  FILE="${DEST}/$db.sql.gz"
  [ -f $FILE ] && mv "$FILE" "${FILE}.old"
  mysqldump --single-transaction --set-gtid-purged=OFF --routines --quick -h $HOSTNAME -u $USER -B $db | gzip > "$FILE"
#  chown bacula:disk "$FILE"
  rm -f "${FILE}.old"
done
