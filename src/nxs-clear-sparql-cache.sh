#!/bin/bash

color='\e[1;34m'         # begin color
error_color='\e[1;32m'   # begin error color
warning_color='\e[1;33m' # begin warning color
_color='\e[0m'           # end Color

set -o errexit  # make your script exit when a command fails.
set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

function echoUsage() {
    echo "usage: $(basename $0) <src_host>" >&2
    echo "Params:"
    echo " <src_host> [kant, crick, uat-web2, nextp-vm2a.vital-it.ch]"
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

if [ $# -lt 1 ]; then
  echo missing arguments
  echoUsage; exit 1
fi


function stop_jetty() {
  host=$1
  if ! ssh npteam@${host} test -f /work/jetty/jetty.pid; then
  echo -e "${warning_color}Jetty was not running at $host ${_color}"
  return 0
  fi
  echo -e "${color}Stopping jetty at ${host}...${_color}"
  ssh npteam@${host} "/work/jetty/bin/jetty.sh stop"
  echo -e "${color}Jetty has been correctly stopped at ${host} ${_color}"
  
  # it seems that jetty.sh stop returns before writing cache index files is completed
  sleep 60
}

function check_cache_index_files() {
  host=$1
  # Check that cache index files exist else exit with an error
  echo -e "${color}Searching cache index files in ${host}${_color}"
  count=`ssh npteam@${host} "ls -1 /work/jetty/cache/*.index 2>/dev/null | wc -l"`

  if [ ${count} == 0 ]; then
    echo -e "${color}Error: missing index cache files in folder ${host}:/work/jetty/cache ${_color}"
    exit 2
  else
    echo -e "${color}Success: cache index files found in folder ${host}:/work/jetty/cache ${_color}"
  fi
}


function start_jetty() {
  host=$1
  echo -e "${color}Starting jetty at ${host}...${_color}"
  ssh npteam@${host} "source .bash_profile; /work/jetty/bin/jetty.sh start"
  echo -e "${color}Jetty has been correctly started at ${host} ${_color}"
}

SRC_HOST=$1

stop_jetty ${SRC_HOST}

echo -e "${color}Removing jetty  sparql-related cache files at ${host}...${_color}"
ssh npteam@${SRC_HOST} rm -f /work/jetty/cache/sparql.*
ssh npteam@${SRC_HOST} rm -f /work/jetty/cache/sparql-proxy-cache.*

check_cache_index_files ${SRC_HOST}
start_jetty ${SRC_HOST}

