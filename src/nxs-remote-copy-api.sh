#!/bin/bash

color='\e[1;34m'         # begin color
error_color='\e[1;32m'   # begin error color
warning_color='\e[1;33m' # begin warning color
_color='\e[0m'           # end Color

set -o errexit  # make your script exit when a command fails.
set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

function echoUsage() {
    echo "usage: $(basename $0) <src_host> <dest_host>" >&2
    echo "Params:"
    echo " <src_host> [kant, crick, uat-web2, jung, nextp-vm2a.vital-it.ch]"
    echo " <dest_host> [kant, crick, uat-web2, jung, nextp-vm2a.vital-it.ch]"
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
}

function start_jetty() {
  host=$1
  echo -e "${color}Starting jetty at ${host}...${_color}"
  ssh npteam@${host} "source .bash_profile; /work/jetty/bin/jetty.sh start"
  echo -e "${color}Jetty has been correctly started at ${host} ${_color}"
}

SRC_HOST=$1
TRG_HOST=$2

stop_jetty ${SRC_HOST}

dirs="webapps cache"
for dir in ${dirs}; do
  echo -e "${color}Copying directory ${dir} to ${TRG_HOST}${_color}"
  echo "ssh npteam@${TRG_HOST} rm -rf /work/jetty/${dir}.new"
  ssh npteam@${TRG_HOST} "rm -rf /work/jetty/${dir}.new"
  echo "ssh npteam@${TRG_HOST} mkdir /work/jetty/${dir}.new"
  ssh npteam@${TRG_HOST} "mkdir /work/jetty/${dir}.new"

  if ssh npteam@${SRC_HOST} test -d /work/jetty/${dir}; then
      echo "ssh npteam@${SRC_HOST} scp /work/jetty/${dir}/* npteam@${TRG_HOST}:/work/jetty/${dir}.new/..."
      ssh npteam@${SRC_HOST} "scp /work/jetty/${dir}/* npteam@${TRG_HOST}:/work/jetty/${dir}.new/"
  elif [ ${dir} = "webapps" ]; then
      echo -e "${error_color}ERROR: /work/jetty/${dir} is missing at ${host} ${_color}"
      exit 2
  else
      echo -e "${warning_color}WARNING: /work/jetty/${dir} is missing at ${host} ${_color}"
  fi
done

start_jetty ${SRC_HOST}

stop_jetty ${TRG_HOST}

for dir in ${dirs}; do
  echo -e "${color}Removing directory ${dir}.bak in ${TRG_HOST}${_color}"
  ssh npteam@${TRG_HOST} "rm -rf /work/jetty/${dir}.bak"
  if ssh npteam@${TRG_HOST} test -d /work/jetty/${dir}; then
    echo -e "${color}Backing up directory ${dir} in ${TRG_HOST}${_color}"
    ssh npteam@${TRG_HOST} "mv /work/jetty/${dir} /work/jetty/${dir}.bak "
  fi
  echo -e "${color}Finalizing directory ${dir} in ${TRG_HOST}${_color}"
  ssh npteam@${TRG_HOST} "mv /work/jetty/${dir}.new /work/jetty/${dir} "
done

start_jetty ${TRG_HOST}
