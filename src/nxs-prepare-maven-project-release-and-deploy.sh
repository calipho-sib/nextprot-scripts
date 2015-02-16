#!/usr/bin/env bash

# This script prepares and deploys a new maven project release on nexus.

set -o errexit  # make your script exit when a command fails.
set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

function echoUsage() {
    echo "This script prepares and deploys a new maven project release on nexus."
    echo "usage: $0 [-hmn] <repo>"
    echo "Params:"
    echo " <repo> maven project git repository"
    echo "Options:"
    echo " -h print usage"
    echo " -m pre: merge branch develop to master"
    echo " -n post: prepare next snapshot version in branch develop"
}

MERGE_DEVELOP_TO_MASTER=
BUILD_NEXT_SNAPSHOT=

while getopts 'hmn' OPTION
do
    case ${OPTION} in
    h) echoUsage
        exit 0
        ;;
    m) MERGE_DEVELOP_TO_MASTER=1
        ;;
    n) BUILD_NEXT_SNAPSHOT=1
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

GIT_REPO=$1

# return the next release version to prepare on master
getNextReleaseVersion () {

    # check it is a maven project
    if [ ! -f "pom.xml" ]; then

        echo "pom.xml was not found: not a maven project"
        return 1
    fi

    # get develop version (http://stackoverflow.com/questions/3545292/how-to-get-maven-project-version-to-the-bash-command-line)
    DEV_VERSION=`mvn org.apache.maven.plugins:maven-help-plugin:2.1.1:evaluate -Dexpression=project.version | grep -Ev '(^\[|Download\w+:)'`
    RELEASE_NAME=`mvn org.apache.maven.plugins:maven-help-plugin:2.1.1:evaluate -Dexpression=project.name | grep -Ev '(^\[|Download\w+:)'`

    if [[ ! ${DEV_VERSION} =~ [0-9]+\.[0-9]+\.[0-9]+-SNAPSHOT ]]; then

        echo "cannot release ${RELEASE_NAME} v${DEV_VERSION}: not a snapshot (develop) version"
        return 3
    fi

    echo ${DEV_VERSION%-*}
}

makeNextDevelopmentVersion () {

    # x.y.z
    version=$1

    if [[ ! ${version} =~ [0-9]+\.[0-9]+\.[0-9]+ ]]; then

        echo "cannot increment ${version} version"
        return 4
    fi

    # extract x.y
    xy=${version%.*}

    # extract z
    developVersion=${version#${xy}.}

    z=$(expr ${developVersion} + 1)

    echo ${xy}.${z}-SNAPSHOT
}

echo "move to ${GIT_REPO}"
cd ${GIT_REPO}

# change branch to master
git checkout master

if [ ${MERGE_DEVELOP_TO_MASTER} ]; then
    echo "merge branch develop to master"
    git merge develop -X theirs
    git push origin master
fi

# get release version to prepare
RELEASE_VERSION=$(getNextReleaseVersion);

echo preparing ${RELEASE_NAME} v${RELEASE_VERSION}...

# prepare new version
mvn versions:set -DnewVersion=${RELEASE_VERSION} -DgenerateBackupPoms=false

git add -A
git commit -m "New release version ${RELEASE_VERSION}"

# create a new release tag
git tag -a v${RELEASE_VERSION} -m "tag v${RELEASE_VERSION}"
git push origin master --tags

# build
mvn clean install

# deploy on nexus

mvn deploy

# change branch to develop
git checkout develop

if [ ${BUILD_NEXT_SNAPSHOT} ]; then

    devVersion=$(makeNextDevelopmentVersion RELEASE_VERSION)

    mvn versions:set -DnewVersion="${devVersion}" -DgenerateBackupPoms=false

    git add -A
    git commit -m "Preparing next development snapshot version ${devVersion}"
    git push origin develop
fi

exit 0