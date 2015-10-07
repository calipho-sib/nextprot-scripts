#!/usr/bin/env bash

cd ${REPO_WO_DEP}
git checkout develop

echo -e 'Yo' >> README.md
bash ${NX_SCRIPTS}/src/nxs-fire-and-prepare-next-release.sh 0.10.0
if [ $? != 5 ]; then
    echo "Assertion failed" >&2
    exit 4
fi
