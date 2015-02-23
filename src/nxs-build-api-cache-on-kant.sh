#!/bin/bash

set -o errexit  # make your script exit when a command fails.
set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

set -x
for i in {1..22}
do
    curl http://build-api.nextprot.org/export/entries/chromosome/${i}.xml -o /dev/null
done

curl http://build-api.nextprot.org/export/entries/chromosome/MT.xml -o /dev/null
curl http://build-api.nextprot.org/export/entries/chromosome/X.xml -o /dev/null
curl http://build-api.nextprot.org/export/entries/chromosome/Y.xml -o /dev/null
curl http://build-api.nextprot.org/export/entries/chromosome/unknown.xml -o /dev/null
