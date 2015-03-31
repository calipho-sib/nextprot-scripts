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
    echo "usage: $0 <repo> <machine>" >&2
    echo "This script deploys repo web app content in dev, build, alpha or pro machine"
    echo "Params:"
    echo " <repo> repository"
    echo " <machine> the machine type to deploy on: dev|build|alpha|pro"
    echo "Options:"
    echo " -h print usage"
    echo " -s skip brunch"
    echo " -b backup previous site (activated for pro machine)"
}

SKIP_BRUNCH=
BACKUP_SITE=

while getopts 'hsb' OPTION
do
    case ${OPTION} in
    h) echoUsage
        exit 0
        ;;
    s) SKIP_BRUNCH=1
        ;;
    b) BACKUP_SITE=1
        ;;
    ?) echoUsage
        exit 1
        ;;
    esac
done

shift $(($OPTIND - 1))

args=("$*")

if [ $# -lt 2 ]; then
  echo "missing arguments: Specify the environment where to deploy [dev,build,alpha,pro] and a directory"  >&2
  echoUsage; exit 1
fi

repo=$1
target=$2

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

echo "bower update"
./node_modules/.bin/bower update

if [ ! ${SKIP_BRUNCH} ]; then
    echo "brunching modules"
    rm -rf build
    ./node_modules/.bin/brunch build -P
else
    echo "no brunch today"
fi

sedcmd="s/NX_ENV/${target}/g"
sed ${sedcmd} build/js/app.js > tmp.dat
mv tmp.dat build/js/app.js

echo "deploying to ${target}"

if [ ${target} = "dev" ]; then
    if [ ${BACKUP_SITE} ]; then
        backupSite ${DEV_HOST} ${DEV_PATH}
    fi
    rsync -auv build/* ${DEV_HOST}:${DEV_PATH}
elif [ ${target} = "pro" ]; then
    backupSite ${PRO_HOST} ${PRO_PATH}
    rsync -auv build/* ${PRO_HOST}:${PRO_PATH}
elif [ ${target} = "build" ]; then
    if [ ${BACKUP_SITE} ]; then
        backupSite ${BUILD_HOST} ${BUILD_PATH}
    fi
    rsync -auv build/* ${BUILD_HOST}:${BUILD_PATH}
elif [ ${target} = "alpha" ]; then
    if [ ${BACKUP_SITE} ]; then
        backupSite ${ALPHA_HOST} ${ALPHA_PATH}
    fi
    rsync -auv build/* ${ALPHA_HOST}:${ALPHA_PATH}
else
    echo "unknown machine type"
fi



