#!/usr/bin/env bash

# This script deploys solr data between 2 machines. It stops solr service on both <src> and <target> hosts,
# rsync the solr directory and restart the solr services.

# ex: bash nxs-remote-copy-solr.sh -n kant crick 
# ex: bash nxs-remote-copy-solr.sh -n kant uat-web2

# Warning: This script assumes that the solr config / indexes are up-to-date on <src_host>.

set -o errexit  # make your script exit when a command fails.
set -o nounset  # exit when your script tries to use undeclared variables.

function echoUsage() {
    echo "usage: $0 [-h] <src_host> <dest_host> [<dest_path> <dest_jetty_port>]"
    echo "Params:"
    echo " <src_host> source host"
    echo " <dest_host> destination host"
    echo "[<dest_path> default: /work/devtools/solr-4.5.0]"
    echo "[<dest_jetty_port> default: 8983]"
    echo "Options:"
    echo " -h print usage"
}

while getopts 'h' OPTION
do
    case ${OPTION} in
    h) echoUsage
        exit 0
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
TRG_PATH="/work/devtools/solr-4.5.0"
TRG_JETTY_PORT=8983

if [ $# -eq 4 ]; then
    TRG_PATH=$3
    TRG_JETTY_PORT=$4
fi

TRG_PATH_NEW="${TRG_PATH}.new/"
TRG_PATH_BACK="${TRG_PATH}.back/"

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

echo "Kill solr on ${SRC_HOST}"
kill_solr ${SRC_HOST}

sleep 10

echo "making solr dir ${TRG_PATH_NEW} on ${TRG_HOST}"
ssh npteam@${TRG_HOST} mkdir -p ${TRG_PATH_NEW}

echo "copying solr from ${SRC_HOST} to ${TRG_HOST}:${TRG_PATH_NEW}"
ssh npteam@${SRC_HOST} rsync -avz --delete /work/devtools/solr-4.5.0/ ${TRG_HOST}:${TRG_PATH_NEW}

echo "Kill solr on ${TRG_HOST}"
kill_solr ${TRG_HOST}

echo "rm -rf ${TRG_PATH_BACK}"
ssh npteam@${TRG_HOST} rm -rf ${TRG_PATH_BACK}
echo "mv ${TRG_PATH} ${TRG_PATH_BACK}"
ssh npteam@${TRG_HOST} mv ${TRG_PATH} ${TRG_PATH_BACK}
echo "mv ${TRG_PATH_NEW} ${TRG_PATH}"
ssh npteam@${TRG_HOST} mv ${TRG_PATH_NEW} ${TRG_PATH}

sleep 5
start_solr ${SRC_HOST} "/work/devtools/solr-4.5.0" 8983
sleep 5
start_solr ${TRG_HOST} ${TRG_PATH} ${TRG_JETTY_PORT}
