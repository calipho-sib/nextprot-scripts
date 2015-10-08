#!/usr/bin/env bash

cd ${REPO_WO_DEP_PATH}
git checkout develop

bash ${NX_SCRIPTS_PATH}/src/nxs-fire-and-prepare-next-release.sh koko

if [ $? != 2 ]; then
    TEST_RESULT+="failed"
    FAILED_TESTS+=($0)
else
    TEST_RESULT+="passed"
fi
