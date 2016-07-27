#!/usr/bin/env bash

function echoUsage() {
    echo "Install the latest nextprot-api fetched from nexus (release or snapshot) at <host>:/work/jetty/ as npteam user."
    echo "usage: $0 [-hds][-w war-version] <host>"
    echo "Params:"
    echo " <host> machine to install nexprot-api on (crick, kant, uat-web2 or jung)"
    echo "Options:"
    echo " -h print usage"
    echo " -d delete jetty cache/"
    echo " -s get nextprot-api from nexus snapshot repository"
}

PROD_HOST='jung'
DELETE_CACHE=
SNAPSHOT=
TMP_PATH="/tmp/nextprot-api-web.war"

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
            exit 2
        fi
    else
        echo "Cannot install a snapshot in production server (${HOST}) - operation aborted."
        exit 3
    fi
fi

function stop_jetty() {
  host=$1
  if ! ssh npteam@${host} test -f /work/jetty/jetty.pid; then
      echo -e "${warning_color}Jetty was not running at $host "
      return 0
  fi

  ssh npteam@${host} "/work/jetty/bin/jetty.sh stop > /dev/null 2>&1 &"
  echo -e "Stopping jetty at ${host}..."

  while ssh npteam@${host} test -f /work/jetty/jetty.pid; do
      sleep 1
      echo -n .
  done

  echo -e "Jetty has been correctly stopped at ${host} "
}

function start_jetty() {
  echo -e "Starting jetty at ${host}..."
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
  echo -e "Jetty has been correctly started at ${host} "
}

function clean_jetty_host() {

    host=$1

    echo -e "removing log files on ${host}"
    ssh npteam@${host} "rm -r /work/jetty/logs/*"

    echo -e "removing nextprot-api-web.war on ${host}"
    ssh npteam@${host} "rm /work/jetty/webapps/nextprot-api-web.war"

    if [ ${DELETE_CACHE} ]; then
        echo -e "removing cache: delete /work/jetty/cache"
        ssh npteam@${HOST} "rm -r /work/jetty/cache"
    else
        echo -e "keeping cache: /work/jetty/cache"
    fi
}

function check_war_size() {
    war=$1
    dest=$2
    downloaded_war_size=$3
    host=$4

    echo -e "fetching ${war} in temporary path $(hostname):${dest}"
    # cast to integer
    declare -i nexus_war_size=$(curl -LsI "${war}" 2>&1 | grep Content-Length | awk '{print $2}' | tail -1 | tr -d '\r')

    echo "nextprot-api-web.war size:"
    echo "  downloaded : ${downloaded_war_size} bytes"
    echo "  expected   : ${nexus_war_size} bytes"

    if (( ${downloaded_war_size} != ${nexus_war_size} )) ; then
        echo "Error while fetching nextprot-api-web.war: ${downloaded_war_size} bytes (expected ${nexus_war_size} bytes)"
        echo "restarting jetty..."
        start_jetty ${host}
        exit 4
    fi
}

function fetch_war_from_nexus() {

    host=$1

    if [ ${SNAPSHOT} ]; then
        war="http://miniwatt:8800/nexus/service/local/artifact/maven/redirect?r=nextprot-snapshot-repo&g=org.nextprot&a=nextprot-api-web&v=LATEST&p=war"
    else
        war="http://miniwatt:8800/nexus/service/local/artifact/maven/redirect?r=nextprot-repo&g=org.nextprot&a=nextprot-api-web&v=RELEASE&p=war"
    fi

    echo curl -L "${war}" -o ${TMP_PATH}
    curl -L "${war}" -o ${TMP_PATH}

    downloaded_war_size=$(wc -c ${TMP_PATH} | awk '{print $1}')

    check_war_size ${war} ${TMP_PATH} ${downloaded_war_size} ${host}
}

function deploy_war_to_host() {

    source_path=$1
    host=$2

    echo deploy ${source_path} to npteam@${host}:/work/jetty/webapps/nextprot-api-web.war
    scp ${source_path} npteam@${host}:/work/jetty/webapps/nextprot-api-web.war
    echo rm ${source_path}
    rm ${source_path}
}

stop_jetty ${HOST}

fetch_war_from_nexus ${HOST}

clean_jetty_host ${HOST}

deploy_war_to_host ${TMP_PATH} ${HOST}

start_jetty ${HOST}
