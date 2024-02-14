#!/bin/bash

##############################
## POSTGRESQL BACKUP CONFIG ##
##############################

# Optional system user to run backups as.  If the user the script is running as doesn't match this
# the script terminates.  Leave blank to skip check.
BACKUP_USER=

# Optional hostname to adhere to pg_hba policies.  Will default to "localhost" if none specified.
HOSTNAME="localhost"

# Optional username to connect to database as.  Will default to "postgres" if none specified.
USERNAME="postgres"

# Password for network using
#PASS="$(cat /usr/local/etc/sqlpass)"

# This dir will be created if it doesn't exist.  This must be writable by the user the script is
# running as.
BACKUP_DIR=/usr/local/backup/postgres/

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
DAYS_TO_KEEP=7

# How many weeks to keep weekly backups
WEEKS_TO_KEEP=5

######################################

###########################
###### FULL BACKUPS #######
###########################

FULL_BACKUP_QUERY="select datname from pg_database where not datistemplate and datallowconn order by datname;"

echo -e "\n\nPerforming full backups"
echo -e "--------------------------------------------\n"

[ ! -d $BACKUP_DIR ] && mkdir -p $BACKUP_DIR

for DATABASE in `PGPASSWORD="$PASS" psql -h "$HOSTNAME" -U "$USERNAME" -At -c "$FULL_BACKUP_QUERY" postgres`
do

	if [ $ENABLE_PLAIN_BACKUPS = "yes" ]
	then
		echo "Plain backup of $DATABASE"
        [ -f $BACKUP_DIR"$DATABASE".sql.gz ] && mv $BACKUP_DIR"$DATABASE".sql.gz $BACKUP_DIR"$DATABASE".sql.gz.old
		set -o pipefail
		if ! PGPASSWORD="$PASS" pg_dump -Fp -h "$HOSTNAME" -U "$USERNAME" "$DATABASE" | gzip > $BACKUP_DIR"$DATABASE".sql.gz.in_progress; then
			echo "[!!ERROR!!] Failed to produce plain backup database $DATABASE" 1>&2
		else
			mv $BACKUP_DIR"$DATABASE".sql.gz.in_progress $BACKUP_DIR"$DATABASE".sql.gz
            rm -rf $BACKUP_DIR"$DATABASE".sql.gz.old
		fi
		set +o pipefail
	fi

	if [ $ENABLE_CUSTOM_BACKUPS = "yes" ]
	then
		echo "Custom backup of $DATABASE"
        [ -f $BACKUP_DIR"$DATABASE".custom ] && mv $BACKUP_DIR"$DATABASE".custom $BACKUP_DIR"$DATABASE".custom.old
		if ! PGPASSWORD="$PASS" pg_dump -Fc -h "$HOSTNAME" -U "$USERNAME" "$DATABASE" -f $BACKUP_DIR"$DATABASE".custom.in_progress; then
			echo "[!!ERROR!!] Failed to produce custom backup database $DATABASE" 1>&2
		else
			mv $BACKUP_DIR"$DATABASE".custom.in_progress $BACKUP_DIR"$DATABASE".custom
            rm -rf $BACKUP_DIR"$DATABASE".custom.old
		fi
	fi

done