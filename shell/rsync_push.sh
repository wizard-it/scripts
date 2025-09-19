#!/bin/bash

export PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin"

# Target paths
TARGETS1="/RX/rxdata/logs/"
TARGETS2=""

# Destination
HOST="10.15.20.121"

# Destination resource
SHARE1="logs"
SHARE2=""

# Login
USER="rxuser"

# Password
SECRET="/etc/rsyncd.scrt"


# BODY
for f in $TARGETS1; do 
    rsync -rz --exclude '/status/' --exclude '/remote/' "$f" --password-file="$SECRET" "$USER"@"$HOST"::"$SHARE1"
done
