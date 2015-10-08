#!/usr/bin/env bash

cd ${REPO_WO_DEP_PATH}
git checkout develop

bash ${NX_SCRIPTS_PATH}/src/nxs-fire-and-prepare-next-release.sh ${CURRENT_REPO_WO_DEP_VERSION_DEVELOP%-SNAPSHOT}

if [ $? != 13 ]; then
    TEST_RESULT+="failed"
    NUM_OF_FAILED_TESTS+=($0)
else
    TEST_RESULT+="passed"
fi
