#!/bin/bash

set -eo pipefail

# Uncoment string below for manual importing variables for backends etc.
#source /etc/confd/confd.env


echo "[confd] Watching update from: $NODES ."

while true; do
    /usr/local/bin/confd -onetime -backend $BACKEND -basic-auth -username $USER -password $PASS $NODESSTRING> /dev/null 2>&1
    sleep 30
done
