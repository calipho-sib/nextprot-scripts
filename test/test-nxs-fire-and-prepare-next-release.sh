#!/bin/bash

set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

function echoUsage() {
    echo "usage: $0 <tmp> " >&2
    echo "Test script nxs-fire-and-prepare-next-release.sh with different use/case scenarii"
    echo "Params:"
    echo " <tmp> temporary directory"
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

if [ $# -lt 1 ]; then
    echo "missing temporary directory"  >&2
    echoUsage; exit 2
fi

calcNextDevVersion () {

    relVersion=`mvn org.apache.maven.plugins:maven-help-plugin:2.1.1:evaluate -Dexpression=project.version | grep -Ev '(^\[|Download\w+:)'`

    if [[ ${relVersion} =~ ([0-9]+)\.([0-9]+)\.[0-9]+ ]]; then
        major=${BASH_REMATCH[1]}
        nextMinor=$((${BASH_REMATCH[2]}+1))
        nextVersion=${major}.${nextMinor}.0
    else
        exit 3
    fi
}

TMP=$1
REPO_WO_DEP=${TMP}/repo/nx-test-deploy-module
REPO_W_DEP=${TMP}/repo/nx-test-deploy-with-dep
NX_SCRIPTS=${TMP}/repo/nextprot-scripts
NX_SCENARIO=${NX_SCRIPTS}/test/scenarii/nxs-fire-and-prepare-next-release

echo "== cloning repositories..."
cd ${TMP}
rm -rf ${TMP}/*
mkdir -p ${TMP}/repo
cd ${TMP}/repo
git clone https://github.com/calipho-sib/nx-test-deploy-module.git
git clone https://github.com/calipho-sib/nx-test-deploy-with-dep.git
git clone https://github.com/calipho-sib/nextprot-scripts.git

echo "== fetching infos..."
cd ${REPO_W_DEP}
git checkout develop
CURRENT_REPO_W_DEP_VERSION_DEVELOP=`mvn org.apache.maven.plugins:maven-help-plugin:2.1.1:evaluate -Dexpression=project.version | grep -Ev '(^\[|Download\w+:)'`
calcNextDevVersion
NEXT_REPO_W_DEP_VERSION_DEVELOP=${nextVersion}

cd ${REPO_WO_DEP}
git checkout develop
CURRENT_REPO_WO_DEP_VERSION_DEVELOP=`mvn org.apache.maven.plugins:maven-help-plugin:2.1.1:evaluate -Dexpression=project.version | grep -Ev '(^\[|Download\w+:)'`
calcNextDevVersion
NEXT_REPO_WO_DEP_VERSION_DEVELOP=${nextVersion}

echo "-- current develop version for nx-test-deploy-module: ${CURRENT_REPO_WO_DEP_VERSION_DEVELOP}"
echo "-- next develop version for nx-test-deploy-module: ${NEXT_REPO_WO_DEP_VERSION_DEVELOP}"
echo "-- current develop version for nx-test-deploy-with-dep: ${CURRENT_REPO_W_DEP_VERSION_DEVELOP}"
echo "-- next develop version for nx-test-deploy-with-dep: ${NEXT_REPO_W_DEP_VERSION_DEVELOP}"

echo "== testing different use/cases... "

for useCaseScript in `ls ${NX_SCENARIO}/*.sh`; do
    echo "-- testing ${useCaseScript}... "
    source ${useCaseScript} ${TMP}
    echo "-- PASSED"
done

