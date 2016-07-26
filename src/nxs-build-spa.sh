#!/bin/bash

set -o errexit  # make your script exit when a command fails.
set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

function echoUsage() {
    echo "usage: $0 <gitrepo> <buildmode>" >&2
    echo "Builds the single page application located at git repository (in dev or prod mode)"
    echo "Params:"
    echo " <gitrepo> git repository"
    echo " <buildmode> dev|pro"
    echo "Options:"
    echo " -h print usage"
}

while getopts 'h' OPTION
do
    case ${OPTION} in
    h) echoUsage
        exit 0
        ;;
    ?) echoUsage
        exit 1
        ;;
    esac
done

shift $(($OPTIND - 1))

args=("$*")

if [ $# -lt 2 ]; then
  echo "missing argument: Specify the build type [dev or pro] and the target git repositiory"  >&2
  echoUsage; exit 1
fi

REPO=$1
BUILD_TYPE=$2

function checkBranchRepo() {

    build_type=$1

    if [ ${build_type} = "pro" ]; then
        branch=$(git rev-parse --abbrev-ref HEAD)
        if [ ! ${branch} = "master" ]; then
            echo "ERROR: cannot deploy from branch '${branch}'; please change to master branch first before deploying to production server"
            exit 3
        fi
    fi
}

function npmAndBowerInstall() {

    build_type=$1

    echo "npm install"
    npm install
    echo "bower install"
    ./node_modules/.bin/bower install

    echo "brunching modules"
    rm -rf build
    if [ ${build_type} = "pro" ]; then
        ./node_modules/.bin/brunch build -P
    else
        ./node_modules/.bin/brunch build
    fi
}

function setBuildVersionInAppJS() {

    echo -n "fetching build number: "
    build_number=`git rev-list HEAD --count`
    echo "${build_number}"

    echo -n "fetching SHA-1 of current commit: "
    git_hash=`git rev-parse --short HEAD`
    echo "${git_hash}"

    replaceBuildToken="s/BUILD_NUMBER/${build_number}/g"
    replaceGitHashToken="s/GIT_HASH/${git_hash}/g"

    echo "replacing BUILD_NUMBER -> ${build_number} in build/js/app.js"
    sed ${replaceBuildToken} build/js/app.js > tmp.dat
    echo "replacing GIT_HASH -> ${git_hash} in build/js/app.js"
    sed ${replaceGitHashToken} tmp.dat > tmp2.dat
    mv tmp2.dat build/js/app.js

    rm tmp*.dat
}

if [ ! -d ${REPO} ]; then
    echo -e "${REPO} is not a directory"
    exit 2
fi

echo "entering git repository ${REPO}"
cd ${REPO}
checkBranchRepo ${BUILD_TYPE}

npmAndBowerInstall ${BUILD_TYPE}
setBuildVersionInAppJS





