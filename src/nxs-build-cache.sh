#!/bin/bash

set -o errexit  # make your script exit when a command fails.
set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

set -x
for i in {1..22}
do
wget http://build-api.nextprot.org/export/entries/chromosome/$i.xml -O /dev/null
done

wget http://build-api.nextprot.org/export/entries/chromosome/MT.xml -O /dev/null
wget http://build-api.nextprot.org/export/entries/chromosome/X.xml -O /dev/null
wget http://build-api.nextprot.org/export/entries/chromosome/Y.xml -O /dev/null
wget http://build-api.nextprot.org/export/entries/chromosome/unknown.xml -O /dev/null

echo "Getting help"
wget http://build-api.nextprot.org/rdf/help/type/all.json -O /dev/null
set +x
