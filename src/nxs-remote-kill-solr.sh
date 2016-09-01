#!/usr/bin/env bash

set -o errexit  # make your script exit when a command fails.
set -o nounset  # exit when your script tries to use undeclared variables.

function echoUsage() {
    echo "usage: $(basename $0) [-h] <host> "
    echo "Params:"
    echo " <host> host running the solr service"
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

if [ $# -lt 1 ]; then
  echo missing arguments >&2
  echoUsage; exit 2
fi


host=$1
solr_pid=$(ssh npteam@${host} ps -ef | grep java | grep nextprot.solr | tr -s " " | cut -f2 -d' ')
if [ -x ${solr_pid} ];then
    echo "solr was not running on ${host}"
else
    echo "killing solr process ${solr_pid} on ${host}"
    ssh npteam@${host} kill ${solr_pid}
fi

