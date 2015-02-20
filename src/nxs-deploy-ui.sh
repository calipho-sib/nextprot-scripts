#!/bin/bash

# This script deploys repo web app content in dev, build, alpha or pro machine

# ex1: bash -x nxs-deploy-ui.sh /Users/fnikitin/Projects/nextprot-ui/ dev
# ex2: bash nxs-deploy-ui.sh /Users/fnikitin/Projects/nextprot-snorql/ dev

set -o errexit  # make your script exit when a command fails.
set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

color='\e[1;34m'         # begin color
error_color='\e[1;32m'   # begin error color
warning_color='\e[1;33m' # begin warning color
_color='\e[0m'           # end Color

function echoUsage() {
    echo "usage: $0 <repo> <[dev|build|alpha|pro]>" >&2
}

function backupSite() {
    host=$1
    path=$2

    echo "backup site at ${host}:/work/site-archives/"
    if ssh ${host} ! test -d /work/site-archives/; then
        ssh ${host} mkdir "/work/site-archives/"
    else
        echo "/work/site-archives/ already exists at ${host}"
    fi
    baseDir=$(ssh ${host} basename ${path})
    ssh ${host} tar -zcvf "/work/site-archives/${baseDir}_$(date +%Y-%m-%d_%H%M%S).tar.gz" ${path}
}

args=("$*")

if [ $# -lt 2 ]; then
  echo "missing arguments: Specify the environment where to deploy [dev,build,alpha,pro] and a directory"  >&2
  echoUsage; exit 1
fi

repo=$1
target=$2

if [ ! -d ${repo} ]; then
    echo -e "${error_color}${repo} is not a directory${_color}"
    exit 2
elif [ ! -f ${repo}/deploy.conf ]; then
    echo -e "${error_color}deploy.conf file was not found in ${repo}${_color}"
    exit 3
fi

source ${repo}/deploy.conf

echo "entering repository ${repo}"
cd ${repo}

echo "updating repository ${repo}"
git pull

echo "brunching modules"
rm -rf build
./node_modules/.bin/brunch build -P

sedcmd="s/NX_ENV/${target}/g"
sed ${sedcmd} build/js/app.js > tmp.dat
mv tmp.dat build/js/app.js

echo "deploying to ${target}"

if [ ${target} = "dev" ]; then
    rsync -auv build/* ${DEV_HOST}:${DEV_PATH}
elif [ ${target} = "pro" ]; then
    backupSite ${PRO_HOST} ${PRO_PATH}
    rsync -auv build/* ${PRO_HOST}:${PRO_PATH}
elif [ ${target} = "build" ]; then
    rsync -auv build/* ${BUILD_HOST}:${BUILD_PATH}
elif [ ${target} = "alpha" ]; then
    rsync -auv build/* ${ALPHA_HOST}:${ALPHA_PATH}
else
    echo "wrong environment"
fi



