#!/usr/bin/env bash

cd ${REPO_WO_DEP_PATH}
git checkout develop

touch yo
yes N | bash ${NX_SCRIPTS_PATH}/src/nxs-fire-and-prepare-next-release.sh ${NEXT_REPO_WO_DEP_VERSION_DEVELOP}
if [ $? != 4 ]; then
    echo "Assertion failed" >&2
    exit 14
fi

echo "reverting to clean git repo..."
rm yo
