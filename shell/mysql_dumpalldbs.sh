#!/bin/bash

export PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin"

# Destiny folder where backups are stored
DEST=/opt/backup/mysql

CURRDATE=$(date +"%F")

# Hostname where MySQL is running
HOSTNAME="localhost"
# User name to make backup
USER="backup"
# File where has the mysql user password
PASS="$(cat /usr/local/etc/sqlpass)"

DATABASES=$(mysql -h $HOSTNAME -u $USER -p$PASS -e "SHOW DATABASES;" | tr -d "| " | grep -v Database)

[ ! -d $DEST ] && mkdir -p $DEST

for db in $DATABASES; do
  FILE="${DEST}/$db.sql.gz"
  FILEDATE=

  # Be sure to make one backup per day
  [ -f $FILE ] && FILEDATE=$(date -r $FILE +"%F")
  [ "$FILEDATE" == "$CURRDATE" ] && continue

  [ -f $FILE ] && mv "$FILE" "${FILE}.old"
  mysqldump --single-transaction --routines --quick -h $HOSTNAME -u $USER -p$PASS -B $db | gzip > "$FILE"
#  chown bacula:disk "$FILE"
  rm -f "${FILE}.old"
done
