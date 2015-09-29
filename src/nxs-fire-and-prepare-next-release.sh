#!/bin/bash

# This script fires indirectly a new production release (through jenkins) and prepares next development release

# ex1: bash -x nxs-fire-and-prepare-next-release.sh 0.2.1

set -o errexit  # make your script exit when a command fails.
set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

function echoUsage() {
    echo "usage: $0 <snapshot-version> [repo]" >&2
    echo "This script fires indirectly a new production release (through jenkins) and prepares next development release with the given version (-SNAPSHOT is added automatically)"
    echo "Params:"
    echo " <snapshot-version> next snapshot version"
    echo " <repo> optional maven project git repository"
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

GIT_REPO="./"
VERSION=

if [ $# -lt 1 ]; then
    echo "missing arguments: Specify the new version (example 0.2.1)"  >&2
    echoUsage; exit 1
else
    VERSION=$1
    if [ $# -eq 2 ]; then
        GIT_REPO=$2
    fi
fi

checkMavenProject () {

    # check it is a maven project
    if [ ! -f "pom.xml" ]; then

        echo "FAILS: pom.xml was not found (not a maven project)"
        exit 2
    fi
}

echo -n "changing to git repository directory '${GIT_REPO}'... "
cd ${GIT_REPO}
echo "OK"

# check it is a maven project
echo -n "checking maven project... "
checkMavenProject
echo "OK"

git checkout develop
git pull origin develop
git checkout master
git pull origin master
git merge -X theirs develop
git add -A
git push origin master
echo "Jenkins will fire at this point or in 5mins (but we don't wait for it to finish) we assume everything is fine :) "
git checkout develop
mvn versions:set -DnewVersion=${VERSION}-SNAPSHOT -DgenerateBackupPoms=false
git add -A
git commit -m "Preparing next development snapshot version v${VERSION}"
git push origin develop
