#!/usr/bin/env bash

# ex: bash nxs-remote-start-solr.sh kant crick 
# ex: bash nxs-remote-start-solr.sh kant uat-web2
# ex: nohup nxs-remote-start-solr.sh uat-web2 jung /work/devtools/solr-4.5.0 44455  > nohup.remote-copy-solr.out 2>&1

set -o errexit  # make your script exit when a command fails.
set -o nounset  # exit when your script tries to use undeclared variables.

function echoUsage() {
    echo "usage: $0 [-h] <host> [<solr_path> <solr_port>]"
    echo "Params:"
    echo " <host> remote host on which solr is to be started"
    echo "[<solr_path> default: /work/devtools/solr-4.5.0]"
    echo "[<solr_port> default: 8983]"
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

args=("$*")

if [ $# -lt 1 ]; then
  echo missing arguments >&2
  echoUsage; exit 2
fi

host=$1

if [ -z "${2:-}" ]; then SOLR_PATH="/work/devtools/solr-4.5.0" ; else SOLR_PATH=$2 ; fi
if [ -z "${3:-}" ]; then SOLR_PORT=8983 ; else SOLR_PORT=$3 ; fi

echo host=$host
echo SOLR_PATH=$SOLR_PATH
echo SOLR_PORT=$SOLR_PORT

solr_pid=$(ssh npteam@${host} ps -ef | grep java | grep nextprot.solr | tr -s " " | cut -f2 -d' ')
if [ ! -z ${solr_pid} ]; then
  echo "solr already running, pid=$solr_pid", start cancelled.
  exit 0
fi

echo "starting solr on ${host} port ${SOLR_PORT}"
ssh npteam@${host} "sh -c 'cd ${SOLR_PATH}/example; nohup java -Dnextprot.solr -Xmx1024m -jar -Djetty.port=${SOLR_PORT} start.jar  > solr.log 2>&1  &'"

