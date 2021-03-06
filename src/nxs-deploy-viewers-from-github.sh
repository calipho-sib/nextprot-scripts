#!/bin/bash

set -o errexit  # make your script exit when a command fails.
set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

color='\e[1;34m'         # begin color
error_color='\e[1;32m'   # begin error color
warning_color='\e[1;33m' # begin warning color
_color='\e[0m'           # end Color

function echoUsage() {
    echo "usage: $(basename $0) <env> <host> <hostpath>" >&2
    echo "This script deploys the last successfully built Single Page Application (SPA) from github in specified host."
    echo "Params:"
    echo " <env> dev|build|alpha|pro"
    echo " <host> host where to deploy app"
    echo " <hostpath> path in host where to deploy app"
    echo " <spa> single page application name ('search' or 'snorql')"
    echo "Options:"
    echo " -h print usage"
    echo " -s get snapshot from miniwatt (master by default)"
}

BACKUP_SITE=
SNAPSHOT=

while getopts 'hs' OPTION
do
    case ${OPTION} in
    h) echoUsage
        exit 0
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

if [ $# -lt 3 ]; then
  echo "missing arguments: Specify the environment where to deploy [dev,build,alpha,pro] and a directory"  >&2
  echoUsage; exit 1
fi

NX_ENV=$1
NX_HOST=$2
NX_PATH=$3

function backupSite() {
    host=$1
    path=$2

    archive="/work/www-archive"

    if ssh ${host} ! test -d ${path}; then
        echo "no ${path} to backup"
        return
    fi

    echo "backup site at ${host}:${archive}"
    if ssh ${host} ! test -d ${archive}; then
        ssh ${host} mkdir ${archive}
    fi
    baseDir=$(ssh ${host} basename ${path})
    echo "backing up ${archive}/${baseDir}_$(date +%Y-%m-%d_%H%M%S).tar.gz"
    ssh ${host} tar -zcf "${archive}/${baseDir}_$(date +%Y-%m-%d_%H%M%S).tar.gz" -C ${path} .
}

BUILD_DIR=/tmp/build/nx-viewers-${NX_ENV}
rm -rf ${BUILD_DIR}
mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}

MASTER_URL=https://github.com/calipho-sib/nextprot-viewers/archive/master.tar.gz
DEV_URL=https://github.com/calipho-sib/nextprot-viewers/archive/develop.tar.gz

if [ ${SNAPSHOT} ]; then
  echo "Taking SNAPSHOT version"
  wget ${DEV_URL} -O ns.tgz
else
  echo "Taking PRODUCTION version"
  wget ${MASTER_URL} -O ns.tgz
fi

#Keep the m option to set a new date
tar -m -zxf ns.tgz
rm ns.tgz

echo "deploying to ${NX_ENV} ${NX_HOST}:${NX_PATH}"

backupSite ${NX_HOST} ${NX_PATH}

if [ ${SNAPSHOT} ]; then
    rsync --delete-before -auv nextprot-viewers-develop/* ${NX_HOST}:${NX_PATH}
else
    rsync --delete-before -auv nextprot-viewers-master/* ${NX_HOST}:${NX_PATH}
fi

cd -
