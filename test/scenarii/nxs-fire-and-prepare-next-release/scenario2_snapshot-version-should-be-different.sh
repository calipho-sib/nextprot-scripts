#!/usr/bin/env bash

cd ${REPO_WO_DEP}
git checkout develop

bash ${NX_SCRIPTS}/src/nxs-fire-and-prepare-next-release.sh ${CURRENT_REPO_WO_DEP_VERSION_DEVELOP%-SNAPSHOT}
if [ $? != 13 ]; then
    echo "Assertion failed" >&2
    exit 4
fi
