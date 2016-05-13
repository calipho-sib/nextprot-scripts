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

NX_ENV=dev
NX_HOST=npteam@crick
NX_PATH=/work/www/dev-search.nextprot.org/

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

BUILD_DIR=/tmp/build/nx-search-ui-${NX_ENV}
rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR
cd $BUILD_DIR

DEV_URL=http://miniwatt:8900/view/cont-dev-deployment/job/nextprot-np1-np2-search-cont-deployment/lastSuccessfulBuild/artifact/nextprot-np1-np2-search.tgz

wget ${DEV_URL} -O ns.tgz

#Keep the m option to set a new date
tar -m -zxf ns.tgz
rm ns.tgz

replaceEnvToken="s/NX_ENV/${NX_ENV}/g"
sed ${replaceEnvToken} js/app.js > tmp.dat
mv tmp.dat js/app.js

echo "deploying to ${NX_ENV} ${NX_HOST}:${NX_PATH}"

backupSite ${NX_HOST} ${NX_PATH}
rsync --delete-before -auv --exclude 'viewers' * ${NX_HOST}:${NX_PATH}

cd -
