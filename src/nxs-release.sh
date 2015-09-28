#!/usr/bin/env bash

# This script prepares and publish a maven artefact to nexus.
# Execute the following command in a jenkins job: yes|nxs-release.sh <repo>

set -o errexit  # make your script exit when a command fails.
set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

function echoUsage() {
    echo "ONLY JENKINS SHOULD EXECUTE THIS SCRIPT. It prepares and deploys a new release on nexus repository."
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

        echo "failed (cannot release ${RELEASE_NAME} v${devVersion}: snapshot (develop) version expected)"
        exit 3
    fi

    RELEASE_VERSION=${devVersion%-*}
}

read -p "The following script should be executed by Jenkins - Are you Jenkins?[y/N] " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Only Jenkins should execute this script!"
    exit 1
fi

echo "changing directory to ${GIT_REPO}"
cd ${GIT_REPO}

echo -n "testing git branch... "
currentBranch=$(git rev-parse --abbrev-ref HEAD)
if [ ! ${currentBranch} = "master" ]; then
    echo "failed (cannot deploy to production nexus repository: master branch expected)"
    exit 2
fi
echo "done"

# get release version to prepare
echo -n "getting next release... "
getNextReleaseVersion
echo "done (${RELEASE_VERSION}")

# prepare new version
echo "preparing ${RELEASE_NAME} v${RELEASE_VERSION}... "
mvn versions:set -DnewVersion=${RELEASE_VERSION} -DgenerateBackupPoms=false

###### Clean, test and deploy on nexus
echo "deploying on nexus release repository... "
mvn clean deploy

###### Add, commit and push to master
echo "adding and committing in git... "
git add -A
git commit -m "New release version ${RELEASE_VERSION}"

echo "tagging and pushing to origin master... "
# create a new release tag
git tag -a v${RELEASE_VERSION} -m "tag v${RELEASE_VERSION}"
git push origin master --tags

exit 0
