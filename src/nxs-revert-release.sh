#!/bin/bash

set -o errexit  # make your script exit when a command fails.
set -o nounset  # exit when your script tries to use undeclared variables.

set -x

function echoUsage() {
    echo "This script revert master branch to the latest release of the git repository"
    echo "usage: $0 [-h] <repo>"
    echo "Params:"
    echo " <repo> git repository"
    echo "Options:"
    echo " -h print usage"
}

getReleaseVersion () {

    # check it is a maven project
    if [ ! -f "pom.xml" ]; then

        echo "pom.xml was not found: not a maven project"
        exit 1
    fi

    # get develop version (http://stackoverflow.com/questions/3545292/how-to-get-maven-project-version-to-the-bash-command-line)
    rel_version=`mvn org.apache.maven.plugins:maven-help-plugin:2.1.1:evaluate -Dexpression=project.version | grep -Ev '(^\[|Download\w+:)'`
    RELEASE_NAME=`mvn org.apache.maven.plugins:maven-help-plugin:2.1.1:evaluate -Dexpression=project.name | grep -Ev '(^\[|Download\w+:)'`

    if [[ ! ${rel_version} =~ [0-9]+\.[0-9]+\.[0-9]+ ]]; then

        echo "cannot release ${RELEASE_NAME} v${rel_version}: not a release version"
        exit 3
    fi

    RELEASE_VERSION=${rel_version}
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

RELEASE_VERSION=
GIT_REPO=$1

echo "move to ${GIT_REPO}"
cd ${GIT_REPO}

echo "git checkout master"
git checkout master

echo "get pom version"
getReleaseVersion

echo "delete tag v${RELEASE_VERSION} local + remote"
git tag -d v${RELEASE_VERSION}
git push origin :refs/tags/v${RELEASE_VERSION}

echo "set version to ${RELEASE_VERSION}-SNAPSHOT"
# prepare new version
mvn versions:set -DnewVersion=${RELEASE_VERSION}-SNAPSHOT -DgenerateBackupPoms=false

echo "add, commit push to master"
git add -A
git commit -m "Revert last release version v${RELEASE_VERSION}"

git push origin master
