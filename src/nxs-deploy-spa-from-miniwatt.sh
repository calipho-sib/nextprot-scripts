#!/bin/bash

set -o errexit  # make your script exit when a command fails.
set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

color='\e[1;34m'         # begin color
error_color='\e[1;32m'   # begin error color
warning_color='\e[1;33m' # begin warning color
_color='\e[0m'           # end Color

function echoUsage() {
    echo "usage: $(basename $0) <env> <host> <hostpath> <spa>" >&2
    echo "This script deploys the last successfully built Single Page Application (SPA) from miniwatt in specified host."
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

if [ $# -lt 4 ]; then
  echo "missing arguments"  >&2
  echoUsage; exit 1
elif [[ ! $4 = "search" && ! $4 = "snorql" ]]; then
  echo "spa should only be 'search' or 'snorql'" >&2
  echoUsage; exit 2
fi

NX_ENV=$1
NX_HOST=$2
NX_PATH=$3
NX_SPA=$4
MASTER_URL=http://miniwatt:8900/view/master-builds/job/nextprot-master-${NX_SPA}-build/lastSuccessfulBuild/artifact/nextprot-master-${NX_SPA}.tgz
DEV_URL=http://miniwatt:8900/view/cont-dev-deployment/job/nextprot-dev-${NX_SPA}-cont-deployment/lastSuccessfulBuild/artifact/nextprot-dev-${NX_SPA}.tgz
BUILD_DIR=/tmp/build/nx-${NX_SPA}-${NX_ENV}

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

function setTokensInAppJS() {
    nx_env=$1

    replaceEnvToken="s/NX_ENV/${nx_env}/g"
    replaceTrackingTokenIfProd="s/IS_PRODUCTION/true/g"

    echo "replacing NX_ENV -> ${nx_env} in build/js/app.js"
    sed ${replaceEnvToken} js/app.js > tmp.dat

    if [ ${nx_env} = "pro" ]; then
        sed ${replaceTrackingTokenIfProd} tmp.dat > tmp2.dat
        echo "replacing IS_PRODUCTION -> true in build/js/app.js"
        mv tmp2.dat js/app.js
    else
        mv tmp.dat js/app.js
    fi

    if [ -f tmp*.dat ]; then
        rm tmp*.dat
    fi
}

function initBuildDir() {
    build_dir=$1

    rm -rf ${build_dir}
    mkdir -p ${build_dir}
}

function fetchLastSuccesfullyBuiltSPA() {

    build_dir=$1

    if [ ${SNAPSHOT} ]; then
      echo "Taking SNAPSHOT version"
      wget ${DEV_URL} -O ${build_dir}/ns.tgz
    else
      echo "Taking PRODUCTION version"
      wget ${MASTER_URL} -O ${build_dir}/ns.tgz
    fi

    cd ${build_dir}

    #Keep the m option to set a new date
    tar -m -zxf ns.tgz
    rm ns.tgz

    setTokensInAppJS ${NX_ENV}
}

echo "init build dir ${BUILD_DIR}"
initBuildDir ${BUILD_DIR}

echo "fetching last successfully built ${NX_SPA} SPA"
fetchLastSuccesfullyBuiltSPA ${BUILD_DIR}

echo "deploying to ${NX_ENV} ${NX_HOST}:${NX_PATH}"
backupSite ${NX_HOST} ${NX_PATH}
rsync --delete-before -auv --exclude 'viewers' * ${NX_HOST}:${NX_PATH}
