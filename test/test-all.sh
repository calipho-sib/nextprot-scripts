#!/usr/bin/env bash

set -o errexit  # make your script exit when a command fails.
set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

function echoUsage() {
    echo "usage: $0 <tmp>" >&2
    echo "Execute all bash script tests locally"
    echo "Params:"
    echo " <tmp> temporary directory"
    echo "Options:"
    echo " -l execute tests from local nextprot-scripts repo"
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

NX_SCRIPTS_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

for i in `ls ${NX_SCRIPTS_PATH}/*.sh | grep -v "test-all.sh"`;  do
    echo "executing local test $i..."
    bash ${i} -l ${TMP};
done
