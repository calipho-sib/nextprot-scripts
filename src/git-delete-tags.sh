#!/bin/bash

set -o errexit  # make your script exit when a command fails.
set -o nounset  # exit when your script tries to use undeclared variables.

set -x

function echoUsage() {
    echo "This script delete tags on local and remote branches master"
    echo "usage: $0 [-h] <repo>"
    echo "Params:"
    echo " <repo> git repository"
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

if [ $# -lt 1 ]; then
  echo missing arguments >&2
  echoUsage; exit 2
fi

TAG_NAME=$1

git checkout master
git tag -d ${TAG_NAME}
git push origin :refs/tags/${TAG_NAME}
git checkout develop
