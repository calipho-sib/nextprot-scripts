#!/bin/bash

set -o errexit  # make your script exit when a command fails.
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

cd ${TMP}
mkdir -p ${TMP}/scenario
cd ${TMP}/scenario
git clone https://github.com/calipho-sib/nx-test-deploy-module.git
git clone https://github.com/calipho-sib/nx-test-deploy-with-dep.git
