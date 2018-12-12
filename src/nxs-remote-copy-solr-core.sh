#!/usr/bin/env bash

# This script deploys solr core data between 2 machines. It stops solr service on both <src> and <target> hosts,
# rsync the solr directory and restart the solr services.

# ex: bash nxs-remote-copy-solr-core.sh kant crick npcvs1

# Warning: This script assumes that the solr config / indexes are up-to-date on <src_host>.

set -o errexit  # make your script exit when a command fails.
set -o nounset  # exit when your script tries to use undeclared variables.

function echoUsage() {
    echo "usage: $(basename $0) [-h] <src_host> <dest_host> <core>"
    echo "Params:"
    echo " <src_host> source host"
    echo " <dest_host> destination host"
    echo " <core> the core to copy (among npentries1, npentries1gold, nppublications1 or npcvs1)"
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

if [[ $# -lt 3 ]]; then
  echo missing arguments >&2
  echoUsage; exit 2
fi

SRC_HOST=$1
TRG_HOST=$2
CORE=$3

SOLR_PATH="/work/devtools/solr-4.5.0/example"
CORE_PATH="${SOLR_PATH}/solr/$CORE"

TRG_CORE_BACK="${SOLR_PATH}/${CORE}.back"
TRG_CORE_NEW="${CORE_PATH}.new/"

# new one
function kill_solr() {
  host=$1
  echo "killing solr process on ${host}"
  solr_pid=$(ssh npteam@${host} ps -ef | grep java | grep nextprot.solr | tr -s " " | cut -f2 -d' ')
  if [[ -x ${solr_pid} ]];then
    echo "solr was not running on ${host}"
  else
    ssh npteam@${host} kill ${solr_pid}
    echo "killed solr process ${solr_pid} on ${host}"
    sleep 5
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
  echo "starting solr on ${host} port ${port}"
  solr_pid=$(ssh npteam@${host} ps -ef | grep java | grep nextprot.solr | tr -s " " | cut -f2 -d' ')
  if [[ -x ${solr_pid} ]];then
    ssh npteam@${host} "source .bash_profile; cd ${path}/example; nohup java -Dnextprot.solr -Xmx2048m -jar -Djetty.port=${port} start.jar  > solr.log 2>&1  &"
    echo "solr started on ${host}"
    sleep 5
  else
    echo "solr was already running on ${host}"
  fi
}

echo -n "checking solr is properly installed on ${SRC_HOST}... "
check_solr ${SRC_HOST} "${CORE_PATH}/"
echo "OK"

echo "Kill solr on ${SRC_HOST}"
kill_solr ${SRC_HOST}

sleep 10

echo "making new solr core dir ${TRG_CORE_NEW} on ${TRG_HOST}"
ssh npteam@${TRG_HOST} mkdir -p ${TRG_CORE_NEW}

echo "copying solr from ${SRC_HOST}:${CORE_PATH}/* to ${TRG_HOST}:${TRG_CORE_NEW}"
ssh npteam@${SRC_HOST} scp -r ${CORE_PATH}/* ${TRG_HOST}:${TRG_CORE_NEW}

echo "Kill solr on ${TRG_HOST}"
kill_solr ${TRG_HOST}

echo "rm -rf ${TRG_HOST}:${TRG_CORE_BACK}"
ssh npteam@${TRG_HOST} "rm -rf ${TRG_CORE_BACK}"

echo "mv ${CORE_PATH} ${TRG_CORE_BACK} in ${TRG_HOST}"
ssh npteam@${TRG_HOST} "if [ -e ${CORE_PATH} ] ; then  mv ${CORE_PATH} ${TRG_CORE_BACK}; fi"
echo "mv ${TRG_CORE_NEW} ${CORE_PATH} in ${TRG_HOST}"
ssh npteam@${TRG_HOST} mv ${TRG_CORE_NEW} ${CORE_PATH}

sleep 5
start_solr ${SRC_HOST} "/work/devtools/solr-4.5.0" 8983
sleep 5
start_solr ${TRG_HOST} "/work/devtools/solr-4.5.0" 8983

echo "end"

