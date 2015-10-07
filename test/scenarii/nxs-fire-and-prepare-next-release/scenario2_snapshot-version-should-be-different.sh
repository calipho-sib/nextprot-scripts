#!/usr/bin/env bash

cd ${REPO_WO_DEP}
git checkout develop

currentDevVersion=`mvn org.apache.maven.plugins:maven-help-plugin:2.1.1:evaluate -Dexpression=project.version | grep -Ev '(^\[|Download\w+:)'`
bash -x ${NX_SCRIPTS}/src/nxs-fire-and-prepare-next-release.sh ${currentDevVersion%-SNAPSHOT}
if [ $? != 13 ]; then
    echo "Assertion failed" >&2
    exit 4
fi