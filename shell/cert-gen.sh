#!/bin/bash
# AUTHOR: Alexander Kornilov <spellbook33@gmail.com>
# MAINTAINER: Alexander Kornilov <spellbook33@gmail.com>
# Version: stable


##################
### Vars block ###
##################

# Version number
VERSION="1.0"
# Current timestamp
TIMESTAMP=$(date +%d.%m.%Y.%H%M%S)
# Applications
SED=$(whereis sed | awk '{print $2}')
TAR=$(whereis tar | awk '{print $2}')
CERTBOT=$(whereis certbot | awk '{print $2}')
OPENSSL=$(whereis openssl | awk '{print $2}')
# Default params
HOST=$(hostname)
TMP="/tmp"
DEBUG="NO"
DST="/etc/letsencrypt"
DOMAINLIST="domain.cfg"
P12="NO"
HAPROXY="NO"
LENC="NO"


#######################
### Functions block ###
#######################

function printHelp() {
echo "
cert-gen, version: $VERSION
(c) Kornilov Alexander, 2020
Usage:
-e|--p12                - create p12 cert for Windows
-h|--haproxy            - create fullchain cert for haproxy(nginx)
-l|--letsencrypt        - renew let's encrypt certs
-u|--user               - user
-p|--password           - password of user
-P|--masterpassword     - password for private keys
-d|--domains            - path to domain list (default: ./domain.cfg)
-o|--output             - destination folder (default: /etc/letsencrypt)
-t|--temp               - temp dir (default: /tmp)
--help                  - print this help message
--debug                 - print result information and exit

Note: You should provide domain list if you use options -e, -h.
Default location is : ./domain.cfg

Examples:
# Make all certs:
cert-gen -l -e -h -P maSterPaSSw0rd


"
exit 0
}

function printDebug() {
    printf "%-20s : %-25s\n" "p12 init" "$P12"
    printf "%-20s : %-25s\n" "haproxy init" "$HAPROXY"
    printf "%-20s : %-25s\n" "let's encrypt renew" "$LENC"
    printf "%-20s : %-25s\n" "user" "$USER"
    printf "%-20s : %-25s\n" "password" "$PASS"
    printf "%-20s : %-25s\n" "master cert password" "$MASTERPASS"
    printf "%-20s : %-25s\n" "domain list file" "$DOMAIN"
    printf "%-20s : %-25s\n" "output dir" "$DST"
    printf "%-20s : %-25s\n" "temp dir" "$TMP"
    exit 0
}

function printError() {
    case "$1" in
        "g1")
            echo "Syntax error! Please, use '--help' to show usage examples."
            ;;
        "t1")
            echo "TMP dir "$TMP" does not exist! Trying to create..."
            ;;
        "t2")
            echo "Can't create or read TMP dir! Check folder "$TMP" permissons. Aborting..."
            ;;
        "t3")
            echo "TMP dir is not writable. Check folder "$TMP" permissons. Aborting...";
            ;;
        "t4")
            echo "Temp dir is empty. Use --temp to provide it. Using default /tmp."
            ;;
        "d1")
            echo "Destination dir "$DST" does not exist! Trying to create..."
            ;;
        "d2")
            echo "Can't create or read destination dir. Check folder "$DST" permissons. Aborting..."
            ;;
        "d3")
            echo "Destination dir is not writable. Check folder "$DST" permissons. Aborting..."
            ;;
        "d4")
            echo "Destination dir is empty. Use --output to provide it. Aborting..."
            ;;
        "d5")
            echo "Domain $DOMAIN does not found. Skiping..."
            ;;
        "d6")
            echo "Domain list $DOMAINLIST does not found. Aborting..."
            ;;
        "d7")
            echo "Domain list is missed. Aborting..."
            ;;
        "c1")
            echo "Can't find CERTBOT app, check certbot pkg installation. Aborting..."
            ;;
        "c2")
            echo "Can't find OPENSSL app, check openssl pkg installation. Aborting..."
            ;;
        "c3")
            echo "You should provide master password (-P option). Aborting..."
            ;;
        *)
            echo "Unknown error."
    esac
}

function checkTmp() {
    if [ -z "$TMP" ]; then TMP="/tmp"; fi
    if [ ! -d "$TMP" ]; then
        printError t1
        mkdir -p $TMP
        if [ ! $? -eq 0 ]; then printError t2; exit 1; fi
    fi
    if [ ! -w "$TMP" ]; then printError t3; exit 1; fi
}

function cleanTmp() {
echo "Cleaning temp folder..."
# rm -rf something
}

function checkDestination() {
    if [ ! -d "$DST" ]; then
        printError d1
        mkdir -p $DST
        if [ ! $? -eq 0 ]; then printError d2; exit 1; fi
    fi
    if [ ! -w "$DST" ]; then printError d3; exit 1; fi
}

function checkParam() {
    if [[ $HAPROXY == "YES" ]] || [[ $P12 == "YES" ]]; then
        if [ -z "$DOMAINLIST" ]; then printError d7; exit 1; fi
    fi
    if [[ $P12 == "YES" ]]; then
        if [ -z "$MASTERPASS" ]; then printError c3; exit 1; fi
    fi
}

function checkDomains() {
    if [ ! -r "$DOMAINLIST" ]; then printError d6; exit 1; fi
}

function updateCerbot() {
    if [ -z "$CERTBOT" ]; then printError c1; exit 1; fi
    echo "$TIMESTAMP : Start updating let's encrypt certificates..."
    $CERTBOT renew --preferred-challenges http --non-interactive
}

function createHaproxy() {
    echo "$TIMESTAMP : Creating haproxy pem certificates..."
    while read DOMAIN
    do
        if [ -z "$DOMAIN" ]; then continue; fi
        if [ ! -d "$DST"/live/"$DOMAIN" ]; then printError d5; continue; fi
        cat "$DST"/live/"$DOMAIN"/fullchain.pem "$DST"/live/"$DOMAIN"/privkey.pem > "$DST"/archive/"$DOMAIN"/haproxy-"$TIMESTAMP".pem
    done < "$DOMAINLIST"   
}

function createP12() {
    if [ -z "$OPENSSL" ]; then printError c2; exit 1; fi
    echo "$TIMESTAMP : Creating p12 type certificates..."
    while read DOMAIN
    do
        if [ -z "$DOMAIN" ]; then continue; fi
        if [ ! -d "$DST"/live/"$DOMAIN" ]; then printError d5; continue; fi
        $OPENSSL pkcs12 -inkey "$DST"/live/"$DOMAIN"/privkey.pem -in "$DST"/live/"$DOMAIN"/fullchain.pem -export -password pass:"$MASTERPASS" -out "$DST"/archive/"$DOMAIN"/windows-"$TIMESTAMP".pfx
    done < "$DOMAINLIST"  
}

function updateLinks() {
    echo "$TIMESTAMP : Updating links..."
    while read DOMAIN
    do
        if [ -z "$DOMAIN" ]; then continue; fi
        if [ ! -d "$DST"/live/"$DOMAIN" ]; then printError d5; continue; fi
        if [[ $HAPROXY == "YES" ]]; then
            rm -rf "$DST"/live/"$DOMAIN"/haproxy.pem
            ln -s ../../archive/"$DOMAIN"/haproxy-"$TIMESTAMP".pem "$DST"/live/"$DOMAIN"/haproxy.pem
        fi
        if [[ $P12 == "YES" ]]; then
            rm -rf "$DST"/live/"$DOMAIN"/exchange.pfx
            rm -rf "$DST"/archive/"$DOMAIN"/exchange.pfx
            ln -s ../../archive/"$DOMAIN"/windows-"$TIMESTAMP".pfx "$DST"/live/"$DOMAIN"/exchange.pfx
            cp -R "$DST"/archive/"$DOMAIN"/windows-"$TIMESTAMP".pfx "$DST"/archive/"$DOMAIN"/exchange.pfx
        fi
    done < "$DOMAINLIST"
}


#########################
### Main (Body) block ###
#########################

# Parsing given arguments
if [[ $# -eq 0 ]]; then printHelp; fi
while [[ $# -gt 0 ]]
do
    ARG="$1"
    case "$ARG" in
        "-e"|"--p12")
            P12="YES"
            shift
            ;;
        "-h"|"--haproxy")
            HAPROXY="YES"
            shift
            ;;
        "-l"|"--letsencrypt")
            LENC="YES"
            shift
            ;;
        "-u"|"--user")
            USER=$2
            shift 2
            ;;
        "-p"|"--password")
            PASS=$2
            shift 2
            ;;
        "-P"|"--masterpassword")
            MASTERPASS=$2
            shift 2
            ;;
        "-d"|"--domain")
            DOMAINLIST=$2
            shift 2
            ;;
        "-o"|"--output")
            DST=$2
            shift 2
            ;;
        "-t"|"--temp")
            TMP=$2
            shift 2
            ;;
        "--debug")
            DEBUG="YES"
            shift
            ;;
        "--help")
            printHelp
            ;;
        *)
            printError g1
            exit 1
            ;;
    esac
done
# Stop for debugging
if [[ "$DEBUG" == "YES" ]]; then printDebug; fi
# Check input params
checkParam
# Check tmp folder
checkTmp
# Check destination
checkDestination
# Generate let's encrypt certificates
if [[ $LENC == "YES" ]]; then
    updateCerbot
fi
# Create haproxy cert
if [[ $HAPROXY == "YES" ]]; then
    checkDomains
    createHaproxy
fi
# Create p12 cert
if [[ $P12 == "YES" ]]; then
    checkDomains
    createP12
fi
# Refresh links
updateLinks
# Some cleaning
cleanTmp
exit 0