#!/bin/bash

# This script fires indirectly a new production release (through jenkins) and prepares next development release

# ex1: bash -x nxs-fire-and-prepare-next-release.sh 0.2.0

set -o errexit  # make your script exit when a command fails.
set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

function echoUsage() {
    echo "usage: $(basename $0) <next-develop-version> [repo]" >&2
    echo "This script does 2 things:"
    echo " 1. it first prepares a release of 'repo' ready for production (merge develop->master) -> this will fire indirectly (through jenkins) the releasing itself (see nxs-release.sh)"
    echo " 2. it then prepares the next development version of 'repo' specified by the argument"
    echo "Params:"
    echo " <next-develop-version> next develop version (MAJOR.MINOR.PATCH)"
    echo " <repo> optional maven project git repository (current directory by default)"
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

checkMavenProject () {

    # check it is a maven project
    if [ ! -f "pom.xml" ]; then

        echo "FAILS: pom.xml was not found (not a maven project)"
        exit 3
    fi

    # get develop version (http://stackoverflow.com/questions/3545292/how-to-get-maven-project-version-to-the-bash-command-line)
    devVersion=`mvn org.apache.maven.plugins:maven-help-plugin:2.1.1:evaluate -Dexpression=project.version | grep -Ev '(^\[|Download\w+:)'`

    if [[ ${devVersion} = ${VERSION}-SNAPSHOT ]]; then

        echo "FAILS: cannot prepare the next development release with the same version number v${VERSION}-SNAPSHOT"
        echo "Choose another <next-snapshot-version>"
        echoUsage
        exit 13
    fi
}

askUserForConfirmation () {

    question=$1
    noteBeforeExit=$2

    echo -en "${question}"
    read -p "[y/N] " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        if [[ ${noteBeforeExit} ]]; then
            echo "** ${noteBeforeExit}"
        fi
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

        git status -s

        while read -r line; do
            if [[ ! ${line} =~ \?\?.* ]]; then
                echo "FAILS: cannot make release (please fix the following file status: ${line})"
                exit 5
            fi
        done <<< "${gitStatus}"

        askUserForConfirmation "!! There are some untracked files in branch $(git rev-parse --abbrev-ref HEAD)\n-- Do you want to proceed for releasing anyway ?" "use 'git add' to track"
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
askUserForConfirmation "Do you want to finalize the merge? " "Note: execute 'git merge --abort' to cancel the merge"
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
