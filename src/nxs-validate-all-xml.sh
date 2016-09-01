#!/bin/bash

set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

function echoUsage() {
    echo "usage: $0 <xsd> <dir>" >&2
    echo "This script validates all xml files found in path dir"
    echo "Params:"
    echo " <xsd> xml schema of a nextprot entry"
    echo " <dir> directory where xml are located"
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

if [ $# -lt 2 ]; then
  echo "missing arguments"  >&2
  echoUsage; exit 1
fi

xsd=$1
dir=$2
validation_file="nxs-validate-all-xml"_with_$(basename ${xsd})

echo "-- push directory ${dir}"
pushd ${dir}
entries=`find . -type f -name '*.xml'`

echo -n "validation with xmllint..."
xmllint --noout --schema ${xsd} ${entries} 2> ${validation_file}.log
echo " Done"

grep -v validate ${validation_file}.log | grep ':' | cut -d: -f3-6|sort|uniq > ${validation_file}.err

echo "-- pop directory"
popd
