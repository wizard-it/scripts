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
MAILNODE1CFG="haproxy.mail.node01.only.cfg"
MAILNODE2CFG="haproxy.mail.node02.only.cfg"
K8SNODE1CFG="haproxy.k8s.node01.only.cfg"
K8SNODE2CFG="haproxy.k8s.node02.only.cfg"
ALLSERVICESCFG="haproxy.all.all.cfg"
MAINCFG="haproxy.cfg"
CFGDIR="/etc/opt/rh/rh-haproxy18/haproxy"
DEBUG="NO"
MANIFEST="NO"

#######################
### Functions block ###
#######################

function printHelp() {
echo "
reconfigure-haproxy, version: $VERSION
(c) Kornilov Alexander, 2021
Usage:
-e|--enable             - enable node and disable all other same type nodes
        Valid params: [mail1, mail2, k8s1, k8s2, all]
            mail1 -->       1st Mail Server
            mail2 -->       2nd Mail Server
            k8s1  -->       1st Kubernetes Server
            k8s2  -->       2nd Kubernetes Server
            all   -->       All of Servers are enabled

-d|--disable            - disable node and enable all other same type nodes
        Valid params: [mail1, mail2, k8s1, k8s2]
            mail1 -->       1st Mail Server
            mail2 -->       2nd Mail Server
            k8s1  -->       1st Kubernetes Server
            k8s2  -->       2nd Kubernetes Server

-c|--configdir          - Set configurations folder. default /etc/opt/rh/rh-haproxy18/haproxy
-l|--list               - Print manifest of local settings

--help                  - print this help message
--debug                 - print result information and exit

Examples:
# Disable 2nd mail server:
reconfigure-haproxy --disable mail2
# Turn on all of servers:
reconfigure-haproxy --enable all

"
exit 0
}

function printError() {
    case "$1" in
        "a1")
            echo "$TIMESTAMP [ERROR]: Unknown configuration name. Type --help to get valid settings"
            ;;
        "a2")
            echo "$TIMESTAMP [ERROR]: Syntax error! Please, use '--help' to show usage examples."
            ;;
        "b1")
            echo "$TIMESTAMP [ERROR]: Configuration file does not found."
            ;;
        "d1")
            echo "$TIMESTAMP [ERROR]: Destination dir "$CFGDIR" does not exist! Trying to create..."
            ;;
        "d2")
            echo "$TIMESTAMP [ERROR]: Can't create or read destination dir. Check folder "$CFGDIR" permissons. Aborting..."
            ;;
        "d3")
            echo "$TIMESTAMP [ERROR]: Config dir is not writable. Check folder "$CFGDIR" permissons. Aborting..."
            ;;
        "r1")
            echo "Do not forget restart haproxy deamon."
            ;;
        *)
            echo "Unknown error."
    esac
}

function printDebug() {
    printf "%-20s : %-25s\n" "Config dir: " "$CFGDIR"
    printf "%-20s : %-25s\n" "Mail Node 1 config " "$MAILNODE1CFG"
    printf "%-20s : %-25s\n" "Mail Node 2 config " "$MAILNODE2CFG"
    printf "%-20s : %-25s\n" "Kubernetes Node 1 config " "$K8SNODE1CFG"
    printf "%-20s : %-25s\n" "Kubernetes Node 2 config " "$K8SNODE2CFG"
    printf "%-20s : %-25s\n" "Action " "$ACTION"
    printf "%-20s : %-25s\n" "Target " "$TARGET"
    printf ""
}

function printManifest() {
    if [[ -f $CFGDIR/Manifest ]]; then
        cat $CFGDIR/Manifest
    else
        echo "File of Manifest is not found."
    fi
    CURCONFIG=$(ls -la $CFGDIR | grep "haproxy.cfg ")
    echo "Current config is $CURCONFIG"
    exit 1
}

function checkDestination() {
    echo "$TIMESTAMP [INFO]: Checking destination folder..."
#    if [ ! -d "$CFGDIR" ]; then
#        printError d1
#        mkdir -p $CFGDIR
#        if [ ! $? -eq 0 ]; then printError d2; exit 1; fi
#    fi
    if [ ! -w "$CFGDIR" ]; then printError d3; exit 1; fi
}

function disableNode() {
        case "$1" in
        "mail1")
            echo "$TIMESTAMP [INFO]: Disabling Mail Node 1..."
            if [[ -f $CFGDIR/$MAILNODE2CFG ]]; then
                rm -rf $CFGDIR/$MAINCFG
                ln -s $CFGDIR/$MAILNODE2CFG $CFGDIR/$MAINCFG
            else
                printError b1
            fi
            ;;
        "mail2")
            echo "$TIMESTAMP [INFO]: Disabling Mail Node 2..."
            if [[ -f $CFGDIR/$MAILNODE1CFG ]]; then
                rm -rf $CFGDIR/$MAINCFG
                ln -s $CFGDIR/$MAILNODE1CFG $CFGDIR/$MAINCFG
            else
                printError b1
            fi
            ;;
        "k8s1")
            echo "$TIMESTAMP [INFO]: Disabling Kubernetes Node 1..."
            if [[ -f $CFGDIR/$K8SNODE2CFG ]]; then
                rm -rf $CFGDIR/$MAINCFG
                ln -s $CFGDIR/$K8SNODE2CFG $CFGDIR/$MAINCFG
            else
                printError b1
            fi
            ;;
        "k8s2")
            echo "$TIMESTAMP [INFO]: Disabling Kubernetes Node 2..."
            if [[ -f $CFGDIR/$K8SNODE1CFG ]]; then
                rm -rf $CFGDIR/$MAINCFG
                ln -s $CFGDIR/$K8SNODE1CFG $CFGDIR/$MAINCFG
            else
                printError b1
            fi          
            ;;
        *)
            printError a1
    esac
}

function enableNode() {
        case "$1" in
        "mail1")
            echo "$TIMESTAMP [INFO]: Enabling Mail Node 1..."
            if [[ -f $CFGDIR/$MAILNODE1CFG ]]; then
                rm -rf $CFGDIR/$MAINCFG
                ln -s $CFGDIR/$MAILNODE1CFG $CFGDIR/$MAINCFG
            else
                printError b1
            fi
            ;;
        "mail2")
            echo "$TIMESTAMP [INFO]: Enabling Mail Node 2..."
            if [[ -f $CFGDIR/$MAILNODE2CFG ]]; then
                rm -rf $CFGDIR/$MAINCFG
                ln -s $CFGDIR/$MAILNODE2CFG $CFGDIR/$MAINCFG
            else
                printError b1
            fi
            ;;
        "k8s1")
            echo "$TIMESTAMP [INFO]: Enabling Kubernetes Node 1..."
            if [[ -f $CFGDIR/$K8SNODE1CFG ]]; then
                rm -rf $CFGDIR/$MAINCFG
                ln -s $CFGDIR/$K8SNODE1CFG $CFGDIR/$MAINCFG
            else
                printError b1
            fi
            ;;
        "k8s2")
            echo "$TIMESTAMP [INFO]: Enabling Kubernetes Node 2..."
            if [[ -f $CFGDIR/$K8SNODE2CFG ]]; then
                rm -rf $CFGDIR/$MAINCFG
                ln -s $CFGDIR/$K8SNODE2CFG $CFGDIR/$MAINCFG
            else
                printError b1
            fi          
            ;;
        "all")
            echo "$TIMESTAMP [INFO]: Enabling ALL Nodes..."
            if [[ -f $CFGDIR/$ALLSERVICESCFG ]]; then
                rm -rf $CFGDIR/$MAINCFG
                ln -s $CFGDIR/$ALLSERVICESCFG $CFGDIR/$MAINCFG
            else
                printError b1
            fi          
            ;;
        *)
            printError a1
    esac
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
        "-d"|"--disable")
            TARGET=$2
            ACTION="disable"
            shift 2
            ;;
        "-e"|"--enable")
            TARGET=$2
            ACTION="enable"
            shift 2
            ;;
        "-c"|"--configdir")
            CFGDIR=$2
            shift 2
            ;;
        "-l"|"--list")
            MANIFEST="YES"
            shift
            ;;
        "--debug")
            DEBUG="YES"
            shift
            ;;
        "--help")
            printHelp
            ;;
        *)
            printError a2
            exit 1
            ;;
    esac
done

# Print debug or mainfest banners
if [[ "$DEBUG" == "YES" ]]; then printDebug; fi
if [[ "$MANIFEST" == "YES" ]]; then printManifest; fi

# Checking block
checkDestination

#Main actions
case $ACTION in
    "enable")
        enableNode $TARGET
        ;;
    "disable")
        disableNode $TARGET
        ;;
    *)
        printError a1
esac

printError r1