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

TMP=$1
REPO_WO_DEP=${TMP}/repo/nx-test-deploy-module
REPO_W_DEP=${TMP}/repo/nx-test-deploy-with-dep
NX_SCRIPTS=${TMP}/repo/nextprot-scripts

cd ${TMP}
rm -rf ${TMP}/*
mkdir -p ${TMP}/repo
cd ${TMP}/repo
git clone https://github.com/calipho-sib/nx-test-deploy-module.git
git clone https://github.com/calipho-sib/nx-test-deploy-with-dep.git
git clone https://github.com/calipho-sib/nextprot-scripts.git

cd ${REPO_WO_DEP}
git checkout develop
ls

# scenario 1: bad snapshot version format: should exit 2
bash -x ${NX_SCRIPTS}/src/nxs-fire-and-prepare-next-release.sh koko
if [ $? != 2 ]; then
    echo "Assertion failed" >&2
    exit 3
fi

# scenario 2: same snapshot version: should exit directly
currentDevVersion=`mvn org.apache.maven.plugins:maven-help-plugin:2.1.1:evaluate -Dexpression=project.version | grep -Ev '(^\[|Download\w+:)'`
bash -x ${NX_SCRIPTS}/src/nxs-fire-and-prepare-next-release.sh ${currentDevVersion%-SNAPSHOT}
if [ $? != 13 ]; then
    echo "Assertion failed" >&2
    exit 4
fi