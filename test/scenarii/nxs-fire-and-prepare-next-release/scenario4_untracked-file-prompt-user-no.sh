#!/usr/bin/env bash

cd ${REPO_WO_DEP_PATH}
git checkout develop

touch yo
yes N | bash ${NX_SCRIPTS_PATH}/src/nxs-fire-and-prepare-next-release.sh ${NEXT_REPO_WO_DEP_VERSION_DEVELOP}

if [ $? != 4 ]; then
    TEST_RESULT+="failed"
    FAILED_TESTS+=($0)
else
    TEST_RESULT+="passed"
fi

echo "reverting to clean git repo..."
rm yo
