#!/usr/bin/env bash

# this script remotely copy PostgreSQL database between 2 machines.
# It stops postgresql on <src> host and rsync the npdb directory to a new directory on the target server

# options:
# -v: verbose mode

# ex: nohup nxs-prepare-remote-copy-npdb.sh -v kant uat-web2 npdb &

set -o errexit  # make your script exit when a command fails.
set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

function echoUsage() {
    echo "usage: $(basename $0) [-c][-v] <src_host> <dest_host> <db_user>"
    echo "Params:"
    echo " <src_host> source host"
    echo " <dest_host> destination host"
    echo " <db_user> db user name at src_host and dest_host"
    echo "Options:"
    echo " -h print usage"
}

while getopts 'hv' OPTION
do
    case ${OPTION} in
    h)  echoUsage
        exit 0
        ;;
    v) set -x
        ;;
    ?) echoUsage
        exit 2
        ;;
    esac
done

function start_pg() {
    host=$1
    user=$2
    # ssh never returns if we don't redirect stdout / stderr to a file
    ssh ${user}@${host} "pg_ctl -D /work/postgres/pg5432_nextprot/ start < /dev/null > pg-start.log 2>&1 &"
}

function stop_pg() {
    host=$1
    user=$2

    set +e
    ssh ${user}@${host} "pg_ctl -D /work/postgres/pg5432_nextprot/ status"

    if [ $? == 0 ]; then
        ssh ${user}@${host} "pg_ctl -D /work/postgres/pg5432_nextprot/ stop -m immediate"
    else
        echo "server not running"
    fi

    set -e
}

function copy_npdb() {
    src=$1
    dest=$2
    dbuser=$3
    dbdir=$4
    dbdirnew=$5
    dbdirback=$6

    echo "deleting /work/postgres/${dbdirback} on target server ${dest}"
    ssh ${dbuser}@${dest} "rm -rf /work/postgres/${dbdirback}"
    
    echo "deleting /work/postgres/${dbdirnew} on target server ${dest}"
    ssh ${dbuser}@${dest} "rm -rf /work/postgres/${dbdirnew}"
    
    echo "making new dir /work/postgres/${dbdirnew} on  target server ${dest}"
    ssh ${dbuser}@${dest} "mkdir -p /work/postgres/${dbdirnew}"
        
    echo "chmod dir /work/postgres/${dbdirnew} on target server ${dest}"
    ssh ${dbuser}@${dest} "chmod 700 /work/postgres/${dbdirnew}"

    # The files are transferred in "archive" mode, which ensures that symbolic links, devices, attributes, permissions,
    # ownerships, etc. are preserved in the transfer.  Additionally, compression will be used to reduce the size of data
    # portions of the transfer.
    
    echo "copying data to /work/postgres/${dbdirnew} on ${dest}"
    ssh npdb@${src} "rsync -avz /work/postgres/${dbdir}/* ${dbuser}@${dest}:/work/postgres/${dbdirnew}"

    # fixing links on prod (was postgresql.conf -> /u01/postgres/config/postgresql_5432.conf)
    if [[ ${dest} = "nextp-vm2a"* ]]; then
        echo "fixing symbolic links on ${dest}..."
        echo "ln -fs /work/postgres/config/pg_hba.conf on target server ${dest}"
        ssh ${dbuser}@${dest} "cd /work/postgres/${dbdirnew}; ln -fs /work/postgres/config/pg_hba.conf"
        echo "ln -fs /work/postgres/config/postgresql.conf"
        ssh ${dbuser}@${dest} "cd /work/postgres/${dbdirnew}; ln -fs /work/postgres/config/postgresql.conf"
    fi
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Main program
# - - - - - - - - - - - - - - - - - - - - - - - - - - - -

shift $(($OPTIND - 1))

args=("$*")

if [ $# -lt 3 ]; then
  echo missing arguments >&2
  echoUsage; exit 1
fi

SRC_HOST=$1
DEST_HOST=$2
DB_USER=$3

DB_DATA_DIR_NAME="pg5432_nextprot"
#DB_DATA_DIR_NAME="testdata"
DB_DATA_DIR_NAME_NEW="${DB_DATA_DIR_NAME}.new"
DB_DATA_DIR_NAME_BACK="${DB_DATA_DIR_NAME}.back"

stop_pg ${SRC_HOST} npdb
sleep 5
copy_npdb ${SRC_HOST} ${DEST_HOST} ${DB_USER} ${DB_DATA_DIR_NAME} ${DB_DATA_DIR_NAME_NEW} ${DB_DATA_DIR_NAME_BACK}
start_pg ${SRC_HOST} npdb

exit 0
