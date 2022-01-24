#!/bin/bash
# AUTHOR: Alexander Kornilov <spellbook33@gmail.com>
# MAINTAINER: Alexander Kornilov <spellbook33@gmail.com>
# Version: stable


##################
### Vars block ###
##################

VERSION="1"

# Hardcoded: Return seconds frm Epoch
# TODO: Rewrite script using input params

date -d "$1" +"%s"


