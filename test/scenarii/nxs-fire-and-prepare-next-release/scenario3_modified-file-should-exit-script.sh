#!/usr/bin/env bash

cd ${REPO_WO_DEP_PATH}
git checkout develop

echo -e 'Yo' >> README.md
bash ${NX_SCRIPTS_PATH}/src/nxs-fire-and-prepare-next-release.sh ${NEXT_REPO_WO_DEP_VERSION_DEVELOP}
if [ $? != 5 ]; then
    echo "Assertion failed" >&2
    exit 13
fi

echo "reverting to clean git repo..."
git checkout -- README.md
