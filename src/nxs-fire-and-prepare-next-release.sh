#!/bin/bash

# This script fires indirectly a new production release (through jenkins) and prepares next development release

# ex1: bash -x nxs-fire-and-prepare-next-release.sh 0.2.0

set -o errexit  # make your script exit when a command fails.
set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

function echoUsage() {
    echo "usage: $0 <next-snapshot-version> [repo]" >&2
    echo "This script fires indirectly a new production release (through jenkins) and prepares next development release with the given version (-SNAPSHOT is added automatically)"
    echo "Params:"
    echo " <next-snapshot-version> next snapshot version (MAJOR.MINOR.PATCH)"
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

checkSnapshotVersion () {

    if [[ ! $1 =~ [0-9]+\.[0-9]+\.[0-9]+ ]]; then

        echo "FAILS: invalid version format (expect version format:'MAJOR.MINOR.PATCH')"
        exit 2
    fi
}

checkSnapshotMajorMinorVersion () {

    if [[ ! $1 =~ [0-9]+\.[0-9]+ ]]; then

        echo "FAILS: invalid version format (expect version format:'MAJOR.MINOR')"
        exit 2
    fi

    if [[ $1 =~ ([0-9]+\.[0-9]+)\.([0-9]+) ]]; then
        VERSION=${BASH_REMATCH[1]}.0
        echo "WARN: patch number '${BASH_REMATCH[2]}' in '$1' will be set to 0"
        echo -n "Reset version to ${VERSION} "
    fi
}

checkMavenProject () {

    # check it is a maven project
    if [ ! -f "pom.xml" ]; then

        echo "FAILS: pom.xml was not found (not a maven project)"
        exit 3
    fi
}

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
            askUserForConfirmation "There are some untracked files in branch $(git rev-parse --abbrev-ref HEAD) - Do you want to proceed for releasing ?"
        else
            echo "FAILS: cannot make release"
            exit 5
        fi
    fi
}

replacePomVersionDepLATESTWithRELEASE () {

    pom=$(cat pom.xml)

    if [[ ${pom} == *"LATEST"* ]]
    then
        echo -n "-- found module dependencies: replacing version 'LATEST' by 'RELEASE'... "
        cat pom.xml | sed -e "s/LATEST/RELEASE/g" > pom.xml.tmp
        mv pom.xml.tmp pom.xml
        git add pom.xml
        git commit -m "Reset module dependencies version LATEST -> RELEASE"
    fi
}

if [ $# -lt 1 ]; then
    echo "missing version number 'MAJOR.MINOR.PATCH' (i.e: 0.2.0)"  >&2
    echoUsage; exit 6
else
    VERSION=$1
    echo -n "-- checking snapshot version argument (${VERSION})... "
    checkSnapshotVersion ${VERSION}
    echo "OK"

    if [ $# -eq 2 ]; then
        GIT_REPO=$2
    fi
fi

echo -n "-- changing to git repository directory '${GIT_REPO}'... "
cd ${GIT_REPO}
echo "OK"

# check it is a maven project
echo -n "-- checking maven project... "
checkMavenProject
echo "OK"

################# DEVELOP BRANCH
git checkout develop
git pull origin develop

checkGitRepo

################# MASTER BRANCH
git checkout master
git pull origin master

checkGitRepo

git merge -X theirs develop --no-commit
git status
askUserForConfirmation "Do you want to commit?"
git commit -m "Merging develop to master for next release"

checkGitRepo

replacePomVersionDepLATESTWithRELEASE
git push origin master

echo "-- Jenkins will fire at this point or in 5mins (but we don't wait for it to finish) we assume everything is fine :) "

################# DEVELOP BRANCH
git checkout develop
mvn versions:set -DnewVersion=${VERSION}-SNAPSHOT -DgenerateBackupPoms=false
git add -A
git commit -m "Preparing next development snapshot version v${VERSION}"
git push origin develop
