#!/usr/bin/env bash

cd ${REPO_WO_DEP_PATH}
git checkout develop

bash ${NX_SCRIPTS_PATH}/src/nxs-fire-and-prepare-next-release.sh koko
if [ $? != 2 ]; then
    echo "Assertion failed" >&2
    exit 11
fi
