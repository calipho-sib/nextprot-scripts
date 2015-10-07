#!/usr/bin/env bash

cd ${REPO_WO_DEP}
git checkout develop

touch yo
printf 'y\nn' | bash ${NX_SCRIPTS}/src/nxs-fire-and-prepare-next-release.sh ${NEXT_REPO_WO_DEP_VERSION_DEVELOP}
if [ $? != 4 ]; then
    echo "Assertion failed" >&2
    exit 15
fi

# reverting to clean git repo
rm yo
