#!/bin/bash

# TODO: Duplicate with scripts nxs-deploy-[snorql|viewers]-from-miniwatt.sh

set -o errexit  # make your script exit when a command fails.
set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

color='\e[1;34m'         # begin color
error_color='\e[1;32m'   # begin error color
warning_color='\e[1;33m' # begin warning color
_color='\e[0m'           # end Color

function echoUsage() {
    echo "usage: $0 <env> <host> <hostpath>" >&2
    echo "This script deploys Single Page Application (SPA) in dev, build, alpha or pro environment."
    echo "Note: SPA has to be built previously with brunch"
    echo "Params:"
    echo " <repo> repository"
    echo " <environment> dev|build|alpha|pro"
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
  echo "missing arguments: Specify the environment where to deploy [dev,build,alpha,pro] and a git repositoy"  >&2
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

function setTokensInAppJS() {
    nx_env=$1

    echo -n "fetching build number: "
    build_number=`git rev-list HEAD --count`
    echo "${build_number}"

    echo -n "fetching SHA-1 of current commit: "
    git_hash=`git rev-parse --short HEAD`
    echo "${git_hash}"

    replaceEnvToken="s/NX_ENV/${nx_env}/g"
    replaceBuildToken="s/BUILD_NUMBER/${build_number}/g"
    replaceGitHashToken="s/GIT_HASH/${git_hash}/g"
    replaceTrackingTokenIfProd="s/IS_PRODUCTION/true/g"

    echo "replacing NX_ENV -> ${nx_env} in build/js/app.js"
    sed ${replaceEnvToken} build/js/app.js > tmp.dat
    echo "replacing BUILD_NUMBER -> ${build_number} in build/js/app.js"
    sed ${replaceBuildToken} tmp.dat > tmp2.dat
    echo "replacing GIT_HASH -> ${git_hash} in build/js/app.js"
    sed ${replaceGitHashToken} tmp2.dat > tmp3.dat

    if [ ${build_type} = "pro" ]; then
        sed ${replaceTrackingTokenIfProd} tmp3.dat > tmp4.dat
        echo "replacing IS_PRODUCTION -> true in build/js/app.js"
        mv tmp4.dat build/js/app.js
    else
        mv tmp3.dat build/js/app.js
    fi

    rm tmp*.dat
}

BUILD_DIR=/tmp/build/nx-search-ui-${NX_ENV}
rm -rf ${BUILD_DIR}
mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}

MASTER_URL=http://miniwatt:8900/view/master-builds/job/nextprot-master-search-build/lastSuccessfulBuild/artifact/nextprot-master-search.tgz
DEV_URL=http://miniwatt:8900/view/cont-dev-deployment/job/nextprot-dev-search-cont-deployment/lastSuccessfulBuild/artifact/nextprot-dev-search.tgz

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

setTokensInAppJS ${NX_ENV}

echo "deploying to ${NX_ENV} ${NX_HOST}:${NX_PATH}"

backupSite ${NX_HOST} ${NX_PATH}
rsync --delete-before -auv --exclude 'viewers' * ${NX_HOST}:${NX_PATH}

cd -
