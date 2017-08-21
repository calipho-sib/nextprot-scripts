#!/usr/bin/env bash

# As npteam, this script remotely copy virtuoso db between 2 machines.
# It stops virtuoso on both <src> and <dest> hosts and rsync the virtuoso db and then restart virtuoso.

# [virtuoso logs are here: /var/lib/virtuoso/db/virtuoso.log]

# kant is the build platform: the source for any deployment
# ex: bash nxs-remote-copy-virtuosodb.sh kant godel
# ex: bash nxs-remote-copy-virtuosodb.sh kant uat-web2

set -o errexit  # make your script exit when a command fails.
set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

function echoUsage() {
    echo "usage: $(basename $0) <src_host> <dest_host>" >&2
}

function check-virtuoso-is-up() {
    host=$1

    if ! ssh npteam@${host} "pgrep virtuoso-t"; then
        echo "WARNING: virtuoso on ${host} was down"
    else 
        echo "virtuoso on ${host} is up as expected, sleeping 30 seconds"
        sleep 30
        echo "performing a checkpoint"
        ssh npteam@${host} isql 1111 dba dba exec="checkpoint;"
        echo "checkpoint done, virtuoso on ${host} is up"
    fi

    return 0
}

function check-virtuoso-is-down() {
    host=$1

    if ssh npteam@${host} "pgrep virtuoso-t"; then
        echo "virtuoso on ${host} is unexpectedly up"
        return 1
    fi
    echo "virtuoso on ${host} is down as expected"

    return 0
}

function stop-virtuoso() {
    host=$1

    # Shut down the server resource: http://tw.rpi.edu/web/inside/endpoints/installing-virtuoso
    ssh npteam@${host} "isql 1111 dba dba -K"

    if [ ! $? = 0 ]; then
        echo "virtuoso on ${host} was not running"
    else
        sleep 30
    fi

    check-virtuoso-is-down ${host}
}

function start-virtuoso() {
    host=$1

    echo "restarting virtuoso on ${host} and wait 30 seconds..."

    # virtuoso-t +configfile: use alternate configuration file
    ssh npteam@${host} "/usr/bin/virtuoso-t +configfile /var/lib/virtuoso/db/virtuoso.ini"
    sleep 30

    check-virtuoso-is-up ${host}
}

function clear-virtuoso() {
    host=$1

    ssh npteam@${host} "mkdir -p /home/npteam/tmp"
    ssh npteam@${host} "cp /var/lib/virtuoso/db/virtuoso.ini /home/npteam/tmp"
    ssh npteam@${host} "rm -rf /var/lib/virtuoso/db/*"
}

function copyDb() {
    src=$1
    dest=$2

    ssh npteam@${src} "rsync -av /var/lib/virtuoso/db/* ${dest}:/var/lib/virtuoso/db"
    ssh npteam@${dest} "rm /var/lib/virtuoso/db/virtuoso.trx"
    ssh npteam@${dest} "cp /home/npteam/tmp/virtuoso.ini /var/lib/virtuoso/db"
    ssh npteam@${dest} "rm -rf /home/npteam/tmp"
}

args=("$*")

if [ $# -lt 2 ]; then
  echo missing arguments >&2
  echoUsage; exit 1
fi

SRC_HOST=$1
DEST_HOST=$2

echo "-"
echo "--- Step 1 --- performing checkpoint on source server"
echo "-"

# if up will perform a checkpoint
check-virtuoso-is-up ${SRC_HOST}

echo "-"
echo "--- Step 2 --- stopping source and target servers"
echo "-"

stop-virtuoso ${SRC_HOST}
stop-virtuoso ${DEST_HOST}

echo "-"
echo "--- Step 3 --- copying data to target server"
echo "-"

# clear the remote virtuoso directory but keep virtuoso.ini
clear-virtuoso ${DEST_HOST}

# copy db from source to dest host
time copyDb ${SRC_HOST} ${DEST_HOST}

echo "-"
echo "--- Step 4 --- restarting source and target servers"
echo "-"

start-virtuoso ${SRC_HOST}
start-virtuoso ${DEST_HOST}

echo "-"
echo "--- DONE ---"
echo "-"
