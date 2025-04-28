#!/bin/bash

export PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin"

##############################
## POSTGRESQL BACKUP CONFIG ##
##############################

# Optional system user to run backups as.  If the user the script is running as doesn't match this
# the script terminates.  Leave blank to skip check.
#BACKUP_USER=

# Labels
TIMESTAMP=$(date +'%d-%b-%Y_%H%M')

# Optional hostname to adhere to pg_hba policies.  Will default to "localhost" if none specified.
HOSTNAME="localhost"

# Optional username to connect to database as.  Will default to "postgres" if none specified.
USERNAME="postgres"

# Password for network using
PASS="$(cat /usr/local/etc/sqlpass)"

# Name of file
FULL_BACKUP_ARCH_NAME="rx_full_bkp"

# List of dirs
BACKUP_DIR_SQL=/usr/local/backup/postgresql
BACKUP_DIR_RX=/usr/local/backup/rx
DATA_DIR=/srv/rxdata
CONFIG_DIR=/srv/DirectumLauncher/etc
# List of strings to match against in database name, separated by space or comma, for which we only
# wish to keep a backup of the schema, not the data. Any database names which contain any of these
# values will be considered candidates. (e.g. "system_log" will match "dev_system_log_2010-01")
SCHEMA_ONLY_LIST=""

# Will produce a custom-format backup if set to "yes"
ENABLE_CUSTOM_BACKUPS=no

# Will produce a gzipped plain-format backup if set to "yes"
ENABLE_PLAIN_BACKUPS=yes

# Will produce gzipped sql file containing the cluster globals, like users and passwords, if set to "yes"
ENABLE_GLOBALS_BACKUPS=no


#### SETTINGS FOR ROTATED BACKUPS ####

# Which day to take the weekly backup from (1-7 = Monday-Sunday)
DAY_OF_WEEK_TO_KEEP=5

# Number of days to keep daily backups
DAYS_TO_KEEP=30

# How many weeks to keep weekly backups
WEEKS_TO_KEEP=5

######################################

###########################
###### FULL BACKUPS #######
###########################

FULL_BACKUP_QUERY="select datname from pg_database where not datistemplate and datallowconn order by datname;"

echo -e "\n\nPerforming SQL backups"
echo -e "--------------------------------------------\n"

[ ! -d $BACKUP_DIR_SQL ] && mkdir -p $BACKUP_DIR_SQL

for DATABASE in `PGPASSWORD="$PASS" psql -h "$HOSTNAME" -U "$USERNAME" -At -c "$FULL_BACKUP_QUERY" postgres`
do

	if [ $ENABLE_PLAIN_BACKUPS = "yes" ]
	then
		echo "Plain backup of $DATABASE"
        [ -f $BACKUP_DIR_SQL/"$DATABASE".sql.gz ] && mv $BACKUP_DIR_SQL/"$DATABASE".sql.gz $BACKUP_DIR_SQL/"$DATABASE".sql.gz.old
		set -o pipefail
		if ! PGPASSWORD="$PASS" pg_dump -Fp -h "$HOSTNAME" -U "$USERNAME" "$DATABASE" | gzip > $BACKUP_DIR_SQL/"$DATABASE".sql.gz.in_progress; then
			echo "[!!ERROR!!] Failed to produce plain backup database $DATABASE" 1>&2
		else
			mv $BACKUP_DIR_SQL/"$DATABASE".sql.gz.in_progress $BACKUP_DIR_SQL/"$DATABASE".sql.gz
            rm -rf $BACKUP_DIR_SQL/"$DATABASE".sql.gz.old
		fi
		set +o pipefail
	fi

done

echo -e "\n\nPerforming full backups"
echo -e "--------------------------------------------\n"

[ ! -d $BACKUP_DIR_RX ] && mkdir -p $BACKUP_DIR_RX
tar -czf $BACKUP_DIR_RX/"$FULL_BACKUP_ARCH_NAME"_$TIMESTAMP.tar.gz --exclude=**/logs/* --exclude=**/_builds/* --exclude=**/_builds_bin/* --exclude=**/_tmp/* -C $(dirname $BACKUP_DIR_SQL) $(basename $BACKUP_DIR_SQL) -C $(dirname $DATA_DIR) $(basename $DATA_DIR) -C $(dirname $CONFIG_DIR) $(basename $CONFIG_DIR)

###########################
###### ROTATE BACKUPS #####
###########################
find $BACKUP_DIR_RX -name "*.tar.gz" -type f -mtime +"$DAYS_TO_KEEP" -delete
