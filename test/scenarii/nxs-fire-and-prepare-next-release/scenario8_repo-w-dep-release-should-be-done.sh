#!/usr/bin/env bash

cd ${REPO_W_DEP_PATH}

yes y | bash ${NX_SCRIPTS_PATH}/src/nxs-fire-and-prepare-next-release.sh ${NEXT_REPO_W_DEP_VERSION_DEVELOP}

if [ $? != 0 ]; then
    TEST_RESULT+="failed"
    FAILED_TESTS+=($0)
else
    echo "TODO: test pom.xml version number in develop"

    TEST_RESULT+="passed"
fi
