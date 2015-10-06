#!/bin/bash

# ex1: bash -x nxs-open-hotfix-branch.sh ~/Projects/nx-test-deploy-module

set -o errexit  # make your script exit when a command fails.
set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

function echoUsage() {
    echo "usage: $0 [repo]" >&2
    echo "This script prepares and inits the next hotfix branch coming from master and checkout to it (after it, you can start fixing it :))"
    echo "Params:"
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

getNextFixVersion () {

    # check it is a maven project
    if [ ! -f "pom.xml" ]; then

        echo "FAILS: pom.xml was not found (not a maven project)"
        exit 2
    fi

    relVersion=`mvn org.apache.maven.plugins:maven-help-plugin:2.1.1:evaluate -Dexpression=project.version | grep -Ev '(^\[|Download\w+:)'`

    if [[ ${relVersion} =~ ([0-9]+\.[0-9]+)\.([0-9]+) ]]; then
        MINOR_VERSION=$((${BASH_REMATCH[2]}+1))
        VERSION=${BASH_REMATCH[1]}.${MINOR_VERSION}
    else
        projectName=`mvn org.apache.maven.plugins:maven-help-plugin:2.1.1:evaluate -Dexpression=project.name | grep -Ev '(^\[|Download\w+:)'`
        echo "WARNING: cannot create fix for ${projectName} v${relVersion} (expected release version)"
        exit 3
    fi
}

checkoutAndPushFixBranch () {

    fixBranch=$1

    echo "-- checking out to branch ${fixBranch}... "

    allBranches=$(git branch -a)

    if [[ ${allBranches} == *${fixBranch}* ]]; then
        git checkout ${fixBranch}
    else
        echo "-- creating new branch ${fixBranch}... "
        git checkout -b ${fixBranch}

        echo "-- changing pom.xml version to v${VERSION}... "
        mvn versions:set -DnewVersion=${VERSION}-SNAPSHOT -DgenerateBackupPoms=false

        git add pom.xml
        git commit -m "preparing fix version v${VERSION}"
        git push -u origin ${fixBranch}
    fi
}

if [ $# -eq 1 ]; then
    GIT_REPO=$1
fi

echo "-- checking out to branch master... "
git checkout master

git pull

echo -n "-- fetching next version... "
getNextFixVersion
echo v${VERSION}

checkoutAndPushFixBranch "hotfix-${VERSION}"

git pull

git status

echo "-- you can now fix your bug in the current branch hotfix-${VERSION}"
exit 0

