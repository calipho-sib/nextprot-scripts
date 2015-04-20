#!/usr/bin/env bash

# This script prepares and deploys a new maven project release on nexus.

set -o errexit  # make your script exit when a command fails.
set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

VERSION=0.1.2

function echoUsage() {
    echo "This script prepares and deploys a new maven project release on nexus."
    echo "usage: $0 [-hmnv] <repo>"
    echo "Params:"
    echo " <repo> maven project git repository"
    echo "Options:"
    echo " -h print usage"
    echo " -v print version"
    echo " -m pre: merge branch develop to master"
    #echo " -n post: prepare next snapshot version in branch develop"
}

MERGE_DEVELOP_TO_MASTER=
BUILD_NEXT_SNAPSHOT=

while getopts 'hmnv' OPTION
do
    case ${OPTION} in
    h) echoUsage
        exit 0
        ;;
    v) echo v${VERSION}
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

RELEASE_VERSION=
NEXT_DEV_VERSION=
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

makeNextDevelopmentVersion () {

    # x.y.z
    version=$1

    if [[ ! ${version} =~ [0-9]+\.[0-9]+\.[0-9]+ ]]; then

        echo "cannot increment ${version} version"
        exit 4
    fi

    # extract x.y
    xy=${version%.*}

    # extract z
    developVersion=${version#${xy}.}

    z=$(expr ${developVersion} + 1)

    NEXT_DEV_VERSION=${xy}.${z}-SNAPSHOT
}

echo "move to ${GIT_REPO}"
cd ${GIT_REPO}

# change branch to develop
git checkout develop
git pull

# change branch to master
git checkout master

if [ ${MERGE_DEVELOP_TO_MASTER} ]; then
    echo "merge branch develop to master"
    git merge develop -X theirs
    git push origin master
fi

# build
mvn clean install #-DskipTests

# get release version to prepare
getNextReleaseVersion

echo preparing ${RELEASE_NAME} v${RELEASE_VERSION}...

# prepare new version
mvn versions:set -DnewVersion=${RELEASE_VERSION} -DgenerateBackupPoms=false

git add -A
git commit -m "New release version ${RELEASE_VERSION}"

# create a new release tag
git tag -a v${RELEASE_VERSION} -m "tag v${RELEASE_VERSION}"
git push origin master --tags

# deploy on nexus
mvn clean deploy

# change branch to develop
git checkout develop

makeNextDevelopmentVersion ${RELEASE_VERSION}
echo "Next development version ready to be set v${RELEASE_VERSION}->v${NEXT_DEV_VERSION}"

#if [ ${BUILD_NEXT_SNAPSHOT} ]; then
#
#    makeNextDevelopmentVersion ${RELEASE_VERSION}
#
#    mvn versions:set -DnewVersion="${NEXT_DEV_VERSION}" -DgenerateBackupPoms=false
#
#    git add -A
#    git commit -m "Preparing next development snapshot version ${NEXT_DEV_VERSION}"
#    git push origin develop
#fi

exit 0