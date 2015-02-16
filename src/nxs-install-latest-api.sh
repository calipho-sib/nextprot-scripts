#!/usr/bin/env bash

info_color='\e[1;34m'    # begin info color
error_color='\e[1;32m'   # begin error color
warning_color='\e[1;33m' # begin warning color
_color='\e[0m'           # end Color

function echoUsage() {
    echo "Install the latest nextprot-api fetched from nexus (release or snapshot) at <host>:/work/jetty/ as npteam user."
    echo "usage: $0 [-hcrs] <host>"
    echo "Params:"
    echo " <host> machine to install nexprot-api on"
    echo "Options:"
    echo " -h print usage"
    echo " -c keep jetty cache/"
    echo " -r keep jetty repository/"
    echo " -s get nextprot-api from nexus snapshot repository"
}

KEEP_CACHE=
KEEP_REPO=
SNAPSHOT=

while getopts 'hcrs' OPTION
do
    case ${OPTION} in
    h) echoUsage
        exit 0
        ;;
    c) KEEP_CACHE=1
        ;;
    r) KEEP_REPO=1
        ;;
    s) SNAPSHOT=1
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

HOST=$1

function stop_jetty() {
  host=$1
  if ! ssh npteam@${host} test -f /work/jetty/jetty.pid; then
      echo -e "${warning_color}Jetty was not running at $host ${_color}"
      return 0
  fi

  ssh npteam@${host} "/work/jetty/bin/jetty.sh stop > /dev/null 2>&1 &"
  echo -e "${info_color}Stopping jetty at ${host}...${_color}"

  while ssh npteam@${host} test -f /work/jetty/jetty.pid; do
      sleep 1
      echo -n .
  done

  echo -e "${info_color}Jetty has been correctly stopped at ${host} ${_color}"
}

function start_jetty() {
  echo -e "${info_color}Starting jetty at ${host}...${_color}"
  host=$1
  ssh npteam@${host} "/work/jetty/bin/jetty.sh start > /dev/null 2>&1 &"
  while ! ssh npteam@${host} "grep -q STARTED /work/jetty/jetty.state 2>/dev/null"; do
      sleep 1
      echo -n .
  done
  echo -e "${info_color}Jetty has been correctly started at ${host} ${_color}"
}

stop_jetty ${HOST}

echo -e "${info_color}removing cache and repository ${_color}"

if [ ! ${KEEP_CACHE} ]; then
    echo -e "${info_color}delete /work/jetty/cache${_color}"
    ssh npteam@${host} "rm -r /work/jetty/cache"
else
    echo -e "${info_color}keeping /work/jetty/cache${_color}"
fi

if [ ! ${KEEP_REPO} ]; then
    echo -e "${info_color}delete /work/jetty/repository${_color}"
    ssh npteam@${host} "rm -r /work/jetty/repository"
else
    echo -e "${info_color}keeping /work/jetty/repository${_color}"
fi

echo -e "${info_color}removing log files ${_color}"
ssh npteam@${host} "rm -r /work/jetty/logs/*"

echo -e "${info_color}removing nextprot-api-web.war${_color}"
ssh npteam@${host} "rm /work/jetty/webapps/nextprot-api-web.war"

LATEST_WAR="http://miniwatt:8800/nexus/service/local/artifact/maven/redirect?r=nextprot-repo&g=org.nextprot&a=nextprot-api-web&v=LATEST&p=war"
if [ ${SNAPSHOT} ]; then
    echo -e "${info_color} getting latest snapshot version ${_color}"
    LATEST_WAR="http://miniwatt:8800/nexus/service/local/artifact/maven/redirect?r=nextprot-snapshot-repo&g=org.nextprot&a=nextprot-api-web&v=LATEST&p=war"
else
    echo -e "${info_color} getting latest release version ${_color}"
fi

ssh npteam@${host} "wget -O /work/jetty/webapps/nextprot-api-web.war \"${LATEST_WAR}\""

start_jetty ${HOST}
