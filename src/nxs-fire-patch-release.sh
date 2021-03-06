#!/bin/bash

# ex1: bash -x nxs-fire-patch-release.sh ~/Projects/nx-test-deploy-module

#set -o errexit  # make your script exit when a command fails.
set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

function echoUsage() {
    echo "usage: $(basename $0) [-hn][repo]" >&2
    echo "This script makes a new patch release.
It merges the hotfix branch back to master, optionally merges to develop with pom.xml versions kept as in develop.
Once it is pushed to origin/master jenkins will publish the new patch with script 'nxs-release.sh'"
    echo "Params:"
    echo " <repo> git maven project (optional parameter)"
    echo "Options:"
    echo " -n no hotfix merge to develop in case of a nextprot dependency changed (ex: new nextprot-queries release)"
    echo " -h print usage"
}

DO_NOT_MERGE_TO_DEVELOP_BRANCH=

while getopts 'hn' OPTION
do
    case ${OPTION} in
    h) echoUsage
        exit 0
        ;;
    n) DO_NOT_MERGE_TO_DEVELOP_BRANCH=1
        ;;
    ?) echoUsage
        exit 1
        ;;
    esac
done

shift $(($OPTIND - 1))

GIT_REPO="./"
VERSION=

askUserForConfirmation () {

    read -p "$1[y/N] " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        echo "-- Exit script on user request"
        exit 4
    fi
}

checkGitRepo () {

    gitStatus=$(git status -s)

    if [[ ${gitStatus} == "" ]]; then
        echo "-- git repository in branch $(git rev-parse --abbrev-ref HEAD) is clean";
    else
        echo "git working directory should be clean!"

        git status

        if [[ ! ${gitStatus} =~ " ??**" ]]; then
            askUserForConfirmation "There are some untracked files in branch $(git rev-parse --abbrev-ref HEAD) - Do you want to proceed for patch releasing ?"
        else
            echo "FAILS: cannot make patch release"
            exit 5
        fi
    fi
}

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

checkoutToNextFixBranch () {

    fixBranch=$1

    echo "-- checking out to branch ${fixBranch}... "

    allBranches=$(git branch -a)

    if [[ ${allBranches} == *${fixBranch}* ]]; then
        git checkout ${fixBranch}
    else
        echo "-- cannot find branch ${fixBranch}: nothing to merge to master and develop!"
        exit 4
    fi
}

mergeToMaster () {

    git checkout master
    #git pull origin master (already done at previous step)
    git merge -X theirs hotfix-${VERSION} --no-commit
    git status
    askUserForConfirmation "Do you want to commit?"
    git commit -m "Merging hotfix-${VERSION} to master for next patch release"

    checkGitRepo

    git push origin master
}

mergeToDevelop () {

    git checkout develop
    #git pull origin develop (already done at previous step)
    git merge hotfix-${VERSION} --no-commit
    echo "fixing conflicts... "
    git checkout --ours pom.xml
    git checkout --ours **/pom.xml
    git add -A
    git commit -m "Merging hotfix-${VERSION} to develop"

    git status
}


if [ $# -eq 1 ]; then
    GIT_REPO=$1
fi

echo "-- checking out to branch master... "
git checkout master
echo "-- git pull origin master... "
git pull origin master

echo -n "-- fetching next version... "
getNextFixVersion
echo v${VERSION}

checkoutToNextFixBranch "hotfix-${VERSION}"
git pull origin hotfix-${VERSION}

echo "-- merging branch hotfix-${VERSION} to master... "
mergeToMaster

if [ ${DO_NOT_MERGE_TO_DEVELOP_BRANCH} ]; then
    echo "-- skipping merge of branch hotfix-${VERSION} to develop"
else
    echo "-- merging branch hotfix-${VERSION} to develop... "
    mergeToDevelop
fi
