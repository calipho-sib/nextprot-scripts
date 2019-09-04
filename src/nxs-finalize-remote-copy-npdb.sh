#!/usr/bin/env bash

# this script stops the postgres server on a host , swaps the current data directory of postgre with a new one, and restarts postgres

# options:
# -v: verbose mode

# ex: nohup nxs-finalize-remote-copy-npdb.sh -v uat-web2 npdb &

set -o errexit  # make your script exit when a command fails. DON'T CHANGE THAT 
set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

DEST_HOST=$1
DB_USER=$2

DATA_DIR="/work/postgres/pg5432_nextprot"
# DATA_DIR="/tmp/pseudopg/datadir"
DATA_DIR_NEW="${DATA_DIR}.new"
DATA_DIR_BACK="${DATA_DIR}.back"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

function echoUsage() {
    echo "usage: $(basename $0) [-c][-v] <dest_host> <db_user>"
    echo "Params:"
    echo " <dest_host> destination host"
    echo " <db_user> db user name at dest_host"
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

	pg_datadir=${DATA_DIR}
	#pg_datadir=/work/postgres/pg5432_nextprot

    # ssh never returns if we don't redirect stdout / stderr to a file
    ssh ${DB_USER}@${DEST_HOST} "pg_ctl -D ${pg_datadir}/ start < /dev/null > pg-start.log 2>&1 &"
}

function stop_pg() {

	pg_datadir=${DATA_DIR}
	#pg_datadir=/work/postgres/pg5432_nextprot

    set +e
    ssh ${DB_USER}@${DEST_HOST} "pg_ctl -D ${pg_datadir}/ status"

    if [ $? == 0 ]; then
        ssh ${DB_USER}@${DEST_HOST} "pg_ctl -D ${pg_datadir}/ stop -m immediate"
    else
        echo "server not running"
    fi
    set -e
}

function swap_db_dir() {

    echo "move ${DATA_DIR} to ${DATA_DIR_BACK} on server ${DEST_HOST}"
    ssh ${DB_USER}@${DEST_HOST} "mv ${DATA_DIR} ${DATA_DIR_BACK}"
    echo "move ${DATA_DIR_NEW} to ${DATA_DIR} on server ${DEST_HOST}"
    ssh ${DB_USER}@${DEST_HOST} "mv ${DATA_DIR_NEW} ${DATA_DIR}"
}

function check_npdb() {

	pg_datadir=${DATA_DIR}
	#pg_datadir=/work/postgres/pg5432_nextprot

    msg=$(ssh ${DB_USER}@${DEST_HOST} "pg_ctl -D ${pg_datadir}/ status|grep PID")

    echo ${msg}

    if [ -z "${msg}" ]; then
        echo "warning: postgresql on  ${DB_USER}@${DEST_HOST} did not correctly restart" >&2
    fi
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

shift $(($OPTIND - 1))
args=("$*")
if [ $# -lt 2 ]; then
  echo missing arguments >&2
  echoUsage; exit 1
fi

echo "Finalizing postgres data copy on ${DEST_HOST} ..."

# check that new dir exists of exits with status 4 (relies on set -o errexit declared above) 
ssh $DB_USER@$DEST_HOST "if [ -e $DATA_DIR_NEW ]; then echo New directory exists; else echo New directory ${DATA_DIR_NEW} NOT found; echo ABORTED; exit 4; fi "

# check that current dir exists of exits with status 5 (relies on set -o errexit declared above)
ssh $DB_USER@$DEST_HOST "if [ -e $DATA_DIR ]; then echo Current directory exists; else echo Current directory ${DATA_DIR} NOT found; echo ABORTED; exit 5; fi "

stop_pg
swap_db_dir
start_pg 
check_npdb

echo DONE
exit 0
