#!/usr/bin/env bash

# This script prepares and deploys a new maven project release on nexus.

set -o errexit  # make your script exit when a command fails.
set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

info_color='\e[1;34m'    # begin info color
error_color='\e[1;32m'   # begin error color
warning_color='\e[1;33m' # begin warning color
_color='\e[0m'           # end Color

function echoUsage() {
    echo "This script prepares and deploys a new maven project release on nexus."
    echo "usage: $0 [-hmd] <repo>"
    echo "Params:"
    echo " <repo> maven project git repository"
    echo "Options:"
    echo " -h print usage"
    echo " -m pre: merge branch develop to master"
    echo " -n post: prepare next snapshot version in branch develop"
}

MERGE_DEVELOP_TO_MASTER=
NEXT_SNAPSHOT_VERSION=

while getopts 'hmn:' OPTION
do
    case ${OPTION} in
    h) echoUsage
        exit 0
        ;;
    m) MERGE_DEVELOP_TO_MASTER=1
        ;;
    n) NEXT_SNAPSHOT_VERSION=$OPTARG
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

REPO=$1

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
        return 2
    fi

    RELEASE_VERSION=${DEV_VERSION%-*}

    return 0
}

cd ${REPO}

# change branch to master
git checkout master

if [ ${MERGE_DEVELOP_TO_MASTER} ]; then
    echo -e "${info_color}merge develop to master${_color}"
    git merge develop -X theirs
    git push origin master
fi

# get release version to prepare
if getNextReleaseVersion RELEASE_VERSION; then

    echo preparing ${RELEASE_NAME} v${RELEASE_VERSION}...

    # prepare new version
    mvn versions:set -DnewVersion=${RELEASE_VERSION} -DgenerateBackupPoms=false

    git add -A
    git commit -m "New release version ${RELEASE_VERSION}"

    # create a new release tag
    git tag -a v${RELEASE_VERSION} -m "tag v${RELEASE_VERSION}"
    git push origin master --tags

    if [ ${NEXT_SNAPSHOT_VERSION} ]; then
        echo -e "${warning_color}in construction${_color}"
        # change branch to develop
        git checkout develop
        mvn versions:set -DnewVersion="${NEXT_SNAPSHOT_VERSION}-SNAPSHOT" -DgenerateBackupPoms=false

        git add -A
        git commit -m "Preparing next development snapshot version ${NEXT_SNAPSHOT_VERSION}"
        git push origin develop
    fi

    # build
    mvn clean install

    # deploy on nexus
    mvn deploy
else
    exit 5
fi

git checkout develop

exit 0