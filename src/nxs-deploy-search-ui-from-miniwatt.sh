#!/bin/bash

# This script build and remotely copy a single page application in dev, build, alpha or pro machine

# ex1: bash -x nxs-build-and-deploy-spa.sh /Users/fnikitin/Projects/nextprot-ui/ dev
# ex2: bash nxs-build-and-deploy-spa.sh /Users/fnikitin/Projects/nextprot-snorql/ dev

set -o errexit  # make your script exit when a command fails.
set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

color='\e[1;34m'         # begin color
error_color='\e[1;32m'   # begin error color
warning_color='\e[1;33m' # begin warning color
_color='\e[0m'           # end Color

function echoUsage() {
    echo "usage: $0 <env> <host> <hostpath>" >&2
    echo "This script builds and deploys web app snapshot (actual branch by default) in dev, build, alpha or pro environment"
    echo "Params:"
    echo " <repo> repository"
    echo " <environment> dev|build|alpha|pro (see deploy.conf for environment to server mapping)"
    echo "Options:"
    echo " -h print usage"
    echo " -s get snapshot from miniwatt (release by default)"
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
    else
        echo "${archive} already exists at ${host}"
    fi
    baseDir=$(ssh ${host} basename ${path})
    ssh ${host} tar -zcvf "${archive}/${baseDir}_$(date +%Y-%m-%d_%H%M%S).tar.gz" ${path}
}

BUILD_DIR=/tmp/build/nx-search-ui-${NX_ENV}
rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR
cd $BUILD_DIR
wget http://miniwatt:8900/view/cont-dev-deployment/job/nextprot-dev-search-cont-deployment/lastSuccessfulBuild/artifact/nextprot-dev-search.tgz -O ns.tgz
tar -zxvf ns.tgz
rm ns.tgz

replaceEnvToken="s/NX_ENV/${NX_ENV}/g"
replaceTrackingTokenIfProd="s/IS_PRODUCTION/true/g"

echo "replacing NX_ENV -> ${NX_ENV} in js/app.js"
sed ${replaceEnvToken} js/app.js > tmp.dat

#if [ ${NX_ENV} = "pro" ]; then
#    sed ${replaceTrackingTokenIfProd} tmp3.dat > tmp4.dat
#    echo "replacing IS_PRODUCTION -> true in build/js/app.js"
#    mv tmp4.dat build/js/app.js
#else
#    mv tmp3.dat build/js/app.js
#fi
#rm tmp*.dat
mv tmp.dat js/app.js

echo "deploying to ${NX_ENV} ${NX_HOST}:${NX_PATH}"

#backupSite ${NX_HOST} ${NX_PATH}
rsync -auv * ${NX_HOST}:${NX_PATH}

cd -