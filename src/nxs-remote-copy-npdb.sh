#!/usr/bin/env bash

# this script remotely copy PostgreSQL database between 2 machines.
# It stops postgresql on both <src> and <dest> hosts and rsync the npdb directory and restart postgresql.

# options:
# -c: activate cold backup mode
# -v: verbose mode

# ex: bash -c nxs-remote-copy-npdb.sh kant uat-web2 npdb

set -o errexit  # make your script exit when a command fails.
set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

function echoUsage() {
    echo "usage: $0 [-c][-v] <src_host> <dest_host> <dest_user>" >&2
}

function start_pg() {
    host=$1
    user=$2
    ssh ${user}@${host} "pg_ctl -D /work/postgres/pg5432_nextprot/ start"
}

function stop_pg() {
    host=$1
    user=$2
    ssh ${user}@${host} "pg_ctl -D /work/postgres/pg5432_nextprot/ stop -m immediate"
}

function copy_npdb() {
    src=$1
    dest=$2
    user=$3
    suffix=$4

    ssh ${user}@${dest} "mkdir -p /work/postgres/pg5432_nextprot${suffix}"

    # The files are transferred in "archive" mode, which ensures that symbolic links, devices, attributes, permissions,
    # ownerships, etc. are preserved in the transfer.  Additionally, compression will be used to reduce the size of data
    # portions of the transfer.
    ssh ${user}@${src} "rsync -avz /work/postgres/pg5432_nextprot/ npdb@${dest}:/work/postgres/pg5432_nextprot${suffix}"
}

function check_npdb() {
    host=$1
    user=$2

    MESS=$(ssh ${user}@${host} "pg_ctl -D /work/postgres/pg5432_nextprot/ status|grep PID")

    echo ${MESS}

    if [ -z ${MESS} ]; then
        echo "warning: postgresql on ${user}@${host} did not correctly restart" >&2
    fi
}

# handle optional arg
coldbackup_flag=

while getopts 'cv' OPTION
do
    case ${OPTION} in
    c)  coldbackup_flag=1
        ;;
    v) set -x
        ;;
    ?) echoUsage
        exit 2
        ;;
    esac
done

shift $(($OPTIND - 1))

args=("$*")

if [ $# -lt 3 ]; then
  echo missing arguments >&2
  echoUsage; exit 1
fi

SRC_HOST=$1
DEST_HOST=$2
DEST_USER=$3

if [ "$coldbackup_flag" ]
  then
    printf "Cold backup activated\n"
fi

stop_pg ${SRC_HOST} ${DEST_USER}
sleep 5

if [ "$coldbackup_flag" ]; then
    stop_pg ${DEST_HOST} ${DEST_USER}
    copy_npdb ${SRC_HOST} ${DEST_HOST} ${DEST_USER}
    start_pg ${DEST_HOST} ${DEST_USER}
else
    copy_npdb ${SRC_HOST} ${DEST_HOST} ${DEST_USER} .back
fi

start_pg ${SRC_HOST} ${DEST_USER}

check_npdb ${DEST_HOST} ${DEST_USER}

exit 0