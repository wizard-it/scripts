#!/bin/bash

export PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin"

# Target paths
TARGETS="/RX/rxdata/logs/"

# Destination
HOST="10.15.20.121"

# Destination resource
SHARE="logs"

# Login
USER="rxuser"

# Password
SECRET="/etc/rsyncd.scrt"


# BODY
for f in $TARGETS; do 
    rsync -rz --exclude '/status/' --exclude '/remote/' "$f" --password-file="$SECRET" "$USER"@"$HOST"::"$SHARE"
done
