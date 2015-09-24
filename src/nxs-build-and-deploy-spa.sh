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
    echo "usage: $0 <repo> <machine>" >&2
    echo "This script builds and deploys web app snapshot (actual branch by default) in dev, build, alpha or pro environment"
    echo "Params:"
    echo " <repo> repository"
    echo " <environment> dev|build|alpha|pro (see deploy.conf for environment to server mapping)"
    echo "Options:"
    echo " -h print usage"
    echo " -b backup previous site (activated for pro machine)"
}

BACKUP_SITE=

while getopts 'hb' OPTION
do
    case ${OPTION} in
    h) echoUsage
        exit 0
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
if [ ${target} = "pro" ]; then
    branch=$(git rev-parse --abbrev-ref HEAD)
    if [ ! ${branch} = "master" ]; then
        echo "ERROR: please change to master branch first before deploying to production server"
        exit 1
    fi
fi

echo -n "fetching build number: "
BUILD_NUMBER=`git rev-list HEAD --count`
echo "${BUILD_NUMBER}"

echo -n "fetching SHA-1 of current commit: "
GIT_HASH=`git rev-parse --short HEAD`
echo "${GIT_HASH}"

echo "updating bower"
./node_modules/.bin/bower update

echo "brunching modules"
rm -rf build
./node_modules/.bin/brunch build -P

replaceEnvToken="s/NX_ENV/${target}/g"
replaceBuildToken="s/BUILD_NUMBER/${BUILD_NUMBER}/g"
replaceGitHashToken="s/GIT_HASH/${GIT_HASH}/g"
replaceTrackingTokenIfProd="s/IS_PRODUCTION/true/g"

echo "replacing NX_ENV -> ${target} in build/js/app.js"
sed ${replaceEnvToken} build/js/app.js > tmp.dat
echo "replacing BUILD_NUMBER -> ${BUILD_NUMBER} in build/js/app.js"
sed ${replaceBuildToken} tmp.dat > tmp2.dat
echo "replacing GIT_HASH -> ${GIT_HASH} in build/js/app.js"
sed ${replaceGitHashToken} tmp2.dat > tmp3.dat

if [ ${target} = "pro" ]; then
    sed ${replaceTrackingTokenIfProd} tmp3.dat > tmp4.dat
    echo "replacing IS_PRODUCTION -> true in build/js/app.js"
    mv tmp4.dat build/js/app.js
else
    mv tmp3.dat build/js/app.js
fi
rm tmp*.dat

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



