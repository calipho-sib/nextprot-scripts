#!/bin/bash

set -o errexit  # make your script exit when a command fails.
set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

function echoUsage() {
    echo "This script changes maven project version snapshot in branch develop"
    echo "usage: $(basename $0) [-h] <repo> <version>"
    echo "Params:"
    echo " <repo> maven project git repository"
    echo " <version> pom version (ie. 1.0.2)"
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
  echo missing arguments >&2
  echoUsage; exit 2
fi

GIT_REPO=$1
VERSION=$2

if [[ ! ${VERSION} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then

    echo "cannot update version to ${VERSION}-SNAPSHOT"
    exit 3
fi

echo "move to ${GIT_REPO}"
cd ${GIT_REPO}

# change branch to develop
git checkout develop
git pull

mvn versions:set -DnewVersion=${VERSION}-SNAPSHOT -DgenerateBackupPoms=false