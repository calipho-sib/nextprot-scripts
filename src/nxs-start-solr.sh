#!/usr/bin/env bash

set -o errexit  # make your script exit when a command fails.
set -o nounset  # exit when your script tries to use undeclared variables.

function echoUsage() {
    echo " "
    echo "usage: $0 [-h] <host> [<path> <port>]" 
    echo " "
    echo "Params:"
    echo " <host> host running the solr service to be killed"
    echo "[<path> location of solr server directory, default: /work/devtools/solr-4.5.0]"
    echo "[<port> solr server port,  default: 8983]"
    echo "Options:"
    echo " -h print usage"
    echo " "
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

if [ $# -lt 1 ]; then
  echo missing arguments >&2
  echoUsage; exit 2
fi

path="/work/devtools/solr-4.5.0"
port=8983

host=$1
if [ $# -eq 3 ]; then
    path=$2
    port=$3
fi

echo "starting solr on ${host} port ${port}"
ssh npteam@${host} "sh -c 'cd ${path}/example; nohup java -Dnextprot.solr -Xmx1524m -jar -Djetty.port=${port} start.jar  > solr.log 2>&1  &'"


