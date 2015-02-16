#!/usr/bin/env bash

# This script deploys solr data between 2 machines. It stops solr service on both <src> and <target> hosts,
# rsync the solr directory and restart the solr services.

# ex: bash nxs-deploy-solr.sh -n crick uat-web2
# ex: bash nxs-deploy-solr.sh -n crick kant /work/devtools/solr/ 8985

# Warning: This script assumes that the solr config / indexes are up-to-date on <src_host>.

set -o errexit  # make your script exit when a command fails.
set -o nounset  # exit when your script tries to use undeclared variables.

function echoUsage() {
    echo "usage: $0 [-hn] <src_host> <dest_host> [<dest_path> <dest_jetty_port>]"
    echo "Params:"
    echo " <src_host> source host"
    echo " <dest_host> destination host"
    echo "Options:"
    echo " -h print usage"
    echo " -n do not clean solr data directories on target server before rsync"
}

# handle optional arg
no_clean_flag=

while getopts 'hn' OPTION
do
    case ${OPTION} in
    h) echoUsage
        exit 0
        ;;
    n) no_clean_flag=1
        ;;
    ?) echoUsage
        exit 1
        ;;
    esac
done

shift $(($OPTIND - 1))

args=("$*")

if [ $# -lt 2 ]; then
  echo missing arguments >&2
  echoUsage; exit 2
fi

SRC_HOST=$1
TRG_HOST=$2
TRG_PATH="/work/devtools/solr-4.5.0/"
TRG_JETTY_PORT=8985

if [ $# -eq 4 ]; then
    TRG_PATH=$3
    TRG_JETTY_PORT=$4
fi

function kill_solr() {

  host=$1
  solr_pid=$(ssh npteam@${host} ps -ef | grep java | grep nextprot.solr | tr -s " " | cut -f2 -d' ')
  if [ -x ${solr_pid} ];then
    echo "solr was not running on ${host}"
  else
    echo "killing solr process ${solr_pid} on ${host}"
    ssh npteam@${host} kill ${solr_pid}
  fi
}

function check_solr() {
  host=$1
  path=$2

  if ! ssh npteam@${host} test -d ${path}; then
    echo "solr was not found at ${host}:${path}"
    exit 3
  fi
}

function start_solr() {
  host=$1
  path=$2
  port=$3

  echo "starting solr on ${host} port ${TRG_JETTY_PORT}"
  ssh npteam@${host} "sh -c 'cd ${path}/example; nohup java -Dnextprot.solr -Xmx1024m -jar -Djetty.port=${port} start.jar  > solr.log 2>&1  &'"
}

echo -n "checking solr is properly installed on ${SRC_HOST}... "
check_solr ${SRC_HOST} "/work/devtools/solr-4.5.0/"
echo "OK"

echo "Attempt to kill solr on ${SRC_HOST} and ${TRG_HOST}"
kill_solr ${SRC_HOST}
kill_solr ${TRG_HOST}

sleep 10

echo "making solr dir ${TRG_PATH} on ${TRG_HOST}"
ssh npteam@${TRG_HOST} mkdir -p ${TRG_PATH}
if [ ! ${no_clean_flag} ]; then
  echo "clearing solr ${TRG_PATH} on ${TRG_HOST}"
  ssh npteam@${TRG_HOST} rm -rf ${TRG_PATH}/*
fi

echo "copying solr from ${SRC_HOST} to ${TRG_HOST}:${TRG_PATH}"
ssh npteam@${SRC_HOST} rsync -avz /work/devtools/solr-4.5.0/ ${TRG_HOST}:${TRG_PATH}

sleep 5
start_solr ${SRC_HOST} "/work/devtools/solr-4.5.0" 8985
sleep 5
start_solr ${TRG_HOST} ${TRG_PATH} ${TRG_JETTY_PORT}
