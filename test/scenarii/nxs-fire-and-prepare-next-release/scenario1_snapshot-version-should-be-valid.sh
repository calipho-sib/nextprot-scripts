#!/usr/bin/env bash

cd ${REPO_WO_DEP}
git checkout develop

bash ${NX_SCRIPTS}/src/nxs-fire-and-prepare-next-release.sh koko
if [ $? != 2 ]; then
    echo "Assertion failed" >&2
    exit 3
fi
echo "TEST PASSED"