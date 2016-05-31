#!/usr/bin/env bash

info_color='\e[1;34m'    # begin info color
error_color='\e[1;32m'   # begin error color
warning_color='\e[1;33m' # begin warning color
_color='\e[0m'           # end Color

function echoUsage() {
    echo "Install the latest nextprot-api fetched from nexus (release or snapshot) at <host>:/work/jetty/ as npteam user."
    echo "usage: $0 [-hds][-w war-version] <host>"
    echo "Params:"
    echo " <host> machine to install nexprot-api on (crick, kant or uat-web2)"
    echo "Options:"
    echo " -h print usage"
    echo " -d delete jetty cache/"
    echo " -s get nextprot-api from nexus snapshot repository"
    echo " -w war-version specific war version to be installed"
}

PROD_HOST='jung'
DELETE_CACHE=
SNAPSHOT=
WAR_VERSION=

while getopts 'hdsw:' OPTION
do
    case ${OPTION} in
    h) echoUsage
        exit 0
        ;;
    d) DELETE_CACHE=1
        ;;
    s) SNAPSHOT=1
        ;;
    w) WAR_VERSION=${OPTARG}
        ;;
    ?) echoUsage
        exit 1
        ;;
    esac
done

shift $(($OPTIND - 1))

args=("$*")

#Setting current hostname if $1 was not defined
HOST=${1:-${HOSTNAME}}

if [ ${HOST} == ${PROD_HOST} ]; then

    # Trying to install release on prod
    if [ ! ${SNAPSHOT} ]; then

        echo "Warning: The standard protocol to release a new stable nextprot-api version to ${PROD_HOST} is:"
        echo "Warning: 1. installation of the latest release in kant (w/ this script)"
        echo "Warning: 2. rebuilt of cache on kant if needed (w/ script nxs-build-api-cache-on-kant.sh)"
        echo "Warning: 3. deployment of api from kant to ${PROD_HOST} (w/ script nxs-deploy-api.sh)"
        echo -n "Are you sure you want to install a release on ${HOST}? [y/N]: "
        read answer
        echo
        if [ "${answer}" != "Y" ] && [ "${answer}" != "y" ]; then
            echo "Release installation to production server (${HOST}) was cancelled."
            exit 3
        fi
    else
        echo "Cannot install a snapshot in production server (${HOST}) - operation aborted."
        exit 4
    fi
fi

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
  # for jung:
  # $ ssh npteam@jung
  # $ exec /work/jetty/bin/jetty.sh start
  # type password !!!
  ssh npteam@${host} "/work/jetty/bin/jetty.sh start > /dev/null 2>&1 &"
  while ! ssh npteam@${host} "grep -q STARTED /work/jetty/jetty.state 2>/dev/null"; do
      sleep 1
      echo -n .
  done
  echo -e "${info_color}Jetty has been correctly started at ${host} ${_color}"
}

stop_jetty ${HOST}

if [ ${DELETE_CACHE} ]; then
    echo -e "${info_color}removing cache: delete /work/jetty/cache${_color}"
    ssh npteam@${HOST} "rm -r /work/jetty/cache"
else
    echo -e "${info_color}keeping cache: /work/jetty/cache${_color}"
fi

echo -e "${info_color}removing log files ${_color}"
ssh npteam@${HOST} "rm -r /work/jetty/logs/*"

echo -e "${info_color}removing nextprot-api-web.war${_color}"
ssh npteam@${HOST} "rm /work/jetty/webapps/nextprot-api-web.war"

if [ ! ${WAR_VERSION} ]; then
    if [ ${SNAPSHOT} ]; then
        WAR_VERSION="LATEST"
    else
        WAR_VERSION="RELEASE"
    fi
fi

WAR="http://miniwatt:8800/nexus/service/local/artifact/maven/redirect?r=nextprot-repo&g=org.nextprot&a=nextprot-api-web&v=${WAR_VERSION}&p=war"
if [ ${SNAPSHOT} ]; then
    WAR="http://miniwatt:8800/nexus/service/local/artifact/maven/redirect?r=nextprot-snapshot-repo&g=org.nextprot&a=nextprot-api-web&v=${WAR_VERSION}&p=war"
fi

echo -e "${info_color} fetching version ${WAR_VERSION} ${WAR}${_color}"
ssh npteam@${HOST} "wget -qO /work/jetty/webapps/nextprot-api-web.war \"${WAR}\""

start_jetty ${HOST}
