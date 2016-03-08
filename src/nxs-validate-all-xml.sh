#!/bin/bash

set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

function echoUsage() {
    echo "usage: $0 <api> <xsd> <output>" >&2
    echo "This script exports all nextprot entries via API and then run xml validation"
    echo "Params:"
    echo " <api> nextprot api host (ie: build-api.nextprot.org)"
    echo " <xsd> xml schema of a nextprot entry"
    echo " <output> directory where to export all xml entries"
    echo "Options:"
    echo " -h print usage"
}

while getopts 'h' OPTION
do
    case ${OPTION} in
    h) echoUsage
        exit 0
        ;;
    ?) echoUsage
        exit 1
        ;;
    esac
done

shift $(($OPTIND - 1))

args=("$*")

if [ $# -lt 3 ]; then
  echo "missing arguments"  >&2
  echoUsage; exit 1
fi

api=$1
xsd=$2
output=$3
validation_file="nxs-validate-all-xml.log"

echo "*** exporting all entries in xml..."
nxs-generate-api-cache-by-entry.py ${api} -o ${output} --format xml

echo "*** copying ${xsd} to output directory ${output}..."
cp ${xsd} ${output}

echo "-- push directory ${output}"
pushd ${output}
entries=`find . -type f -name '*.xml'`

echo "*** validating all entries ..."

echo "validation with xmllint..."
time xmllint --noout --schema ${xsd} ${entries} 2> nxs-validate-all-xml.log &
echo "Done"

grep -v validate nxs-validate-all-xml.log|grep ':' | cut -d: -f3-6|sort|uniq > nxs-validate-all-xml.err

echo "-- pop directory"
popd