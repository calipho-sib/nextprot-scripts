#!/usr/bin/env bash

# This script prepares and publish a maven artefact to nexus.

set -o errexit  # make your script exit when a command fails.
set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

function echoUsage() {
    echo "This script prepares and deploys a new maven project release on nexus."
    echo "usage: $0 [-h] <repo>"
    echo "Params:"
    echo " <repo> maven project git repository"
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

RELEASE_VERSION=
GIT_REPO=$1

# return the next release version to prepare on master
getNextReleaseVersion () {

    # check it is a maven project
    if [ ! -f "pom.xml" ]; then

        echo "pom.xml was not found: not a maven project"
        exit 2
    fi

    # get develop version (http://stackoverflow.com/questions/3545292/how-to-get-maven-project-version-to-the-bash-command-line)
    devVersion=`mvn org.apache.maven.plugins:maven-help-plugin:2.1.1:evaluate -Dexpression=project.version | grep -Ev '(^\[|Download\w+:)'`
    RELEASE_NAME=`mvn org.apache.maven.plugins:maven-help-plugin:2.1.1:evaluate -Dexpression=project.name | grep -Ev '(^\[|Download\w+:)'`

    if [[ ! ${devVersion} =~ [0-9]+\.[0-9]+\.[0-9]+-SNAPSHOT ]]; then

        echo "cannot release ${RELEASE_NAME} v${devVersion}: not a snapshot (develop) version"
        exit 3
    fi

    RELEASE_VERSION=${devVersion%-*}
}

echo "move to ${GIT_REPO}"
cd ${GIT_REPO}

# get release version to prepare
getNextReleaseVersion

# prepare new version
echo preparing ${RELEASE_NAME} v${RELEASE_VERSION}...
mvn versions:set -DnewVersion=${RELEASE_VERSION} -DgenerateBackupPoms=false

###### Clean, test and deploy on nexus
mvn clean deploy

###### Add, commit and push to master
git add -A
git commit -m "New release version ${RELEASE_VERSION}"

# create a new release tag
git tag -a v${RELEASE_VERSION} -m "tag v${RELEASE_VERSION}"
git push origin master --tags

exit 0
