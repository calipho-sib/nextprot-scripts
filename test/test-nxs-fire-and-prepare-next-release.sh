#!/bin/bash

set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

function echoUsage() {
    echo "usage: $0 [-l] <tmp> " >&2
    echo "Test script nxs-fire-and-prepare-next-release.sh with different use/case scenarii"
    echo "Params:"
    echo " <tmp> temporary directory"
    echo "Options:"
    echo " -l execute tests from local nextprot-scripts repo"
    echo " -h print usage"
}

LOCAL_TESTS=0

while getopts 'hl' OPTION
do
    case ${OPTION} in
    h) echoUsage
        exit 0
        ;;
    l) LOCAL_TESTS=1
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

TMP_DIR=$1

if [ ! -d "${TMP_DIR}" ]; then
    echo "temporary directory ${TMP_DIR} does not exist"  >&2
    echoUsage; exit 3
fi

calcNextDevVersion () {

    relVersion=`mvn org.apache.maven.plugins:maven-help-plugin:2.1.1:evaluate -Dexpression=project.version | grep -Ev '(^\[|Download\w+:)'`

    if [[ ${relVersion} =~ ([0-9]+)\.([0-9]+)\.[0-9]+ ]]; then
        major=${BASH_REMATCH[1]}
        nextMinor=$((${BASH_REMATCH[2]}+1))
        nextVersion=${major}.${nextMinor}.0
    else
        exit 4
    fi
}

NX_SCRIPTS_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )"

echo "== cloning repositories..."
echo "-- change to directory ${TMP_DIR}/..."
cd ${TMP_DIR}

TMP_PATH=$(pwd)
REPO_WO_DEP_PATH=${TMP_PATH}/repo/nx-test-deploy-module
REPO_W_DEP_PATH=${TMP_PATH}/repo/nx-test-deploy-with-dep

echo "-- wipe out content..."
rm -rf *
mkdir repo
cd repo

if [ ${LOCAL_TESTS} == 0 ]; then
    echo "-- cloning nextprot-scripts repo... "
    git clone https://github.com/calipho-sib/nextprot-scripts.git
    NX_SCRIPTS_PATH=${TMP_PATH}/repo/nextprot-scripts
fi

NX_SCENARIO_PATH=${NX_SCRIPTS_PATH}/test/scenarii/nxs-fire-and-prepare-next-release

echo "-- cloning nx-test-deploy-module repo... "
git clone https://github.com/calipho-sib/nx-test-deploy-module.git
echo "-- cloning nx-test-deploy-with-dep repo... "
git clone https://github.com/calipho-sib/nx-test-deploy-with-dep.git

echo "== fetching infos..."
cd ${REPO_W_DEP_PATH}
git checkout develop
CURRENT_REPO_W_DEP_VERSION_DEVELOP=`mvn org.apache.maven.plugins:maven-help-plugin:2.1.1:evaluate -Dexpression=project.version | grep -Ev '(^\[|Download\w+:)'`
calcNextDevVersion
NEXT_REPO_W_DEP_VERSION_DEVELOP=${nextVersion}

cd ${REPO_WO_DEP_PATH}
git checkout develop
CURRENT_REPO_WO_DEP_VERSION_DEVELOP=`mvn org.apache.maven.plugins:maven-help-plugin:2.1.1:evaluate -Dexpression=project.version | grep -Ev '(^\[|Download\w+:)'`
calcNextDevVersion
NEXT_REPO_WO_DEP_VERSION_DEVELOP=${nextVersion}

echo "-- current develop version for nx-test-deploy-module: ${CURRENT_REPO_WO_DEP_VERSION_DEVELOP}"
echo "-- next develop version for nx-test-deploy-module: ${NEXT_REPO_WO_DEP_VERSION_DEVELOP}"
echo "-- current develop version for nx-test-deploy-with-dep: ${CURRENT_REPO_W_DEP_VERSION_DEVELOP}"
echo "-- next develop version for nx-test-deploy-with-dep: ${NEXT_REPO_W_DEP_VERSION_DEVELOP}"

echo "== testing different use/cases... "

TEST_RESULTS=()
NUM_OF_FAILED_TESTS=()
for useCaseScript in `ls ${NX_SCENARIO_PATH}/*.sh`; do
    testName=$(basename ${useCaseScript%.sh})
    echo "-- testing ${testName}... "

    TEST_RESULT="${testName}:"
    source ${useCaseScript} ${TMP_PATH}

    echo ${TEST_RESULT}
    TEST_RESULTS+=(${TEST_RESULT})
done

NUM_OF_PASSED_TESTS=$((${#TEST_RESULTS[*]}-${#NUM_OF_FAILED_TESTS[*]}))

echo
echo "=> ${NUM_OF_PASSED_TESTS}/${#TEST_RESULTS[*]} tests passed"

printf '%s\n' "${TEST_RESULTS[@]}"

if [ ${#NUM_OF_FAILED_TESTS[*]} == 0 ]; then
    exit 0
else
    exit 2
fi