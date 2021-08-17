#!/bin/bash
# AUTHOR: Alexander Kornilov <spellbook33@gmail.com>
# MAINTAINER: Alexander Kornilov <spellbook33@gmail.com>
# Version: stable


##################
### Vars block ###
##################

VERSION="1"

# Hardcoded: normalizing files in ansible project
# TODO: Rewrite script using input params

sed -e 's/^[ \t]*// ; s/[[:blank:]]*$// ; s/\s\+/_/g ; s/,$//' hosts_dyn_zabbix | tee hosts_dyn_zabbix
cd host_vars
find . -name "* *" -type f -print0 | \
while read -d $'\0' f; do 
  mv -v "$f" "${f// /_}"; 
done

