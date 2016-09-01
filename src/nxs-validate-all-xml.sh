#!/bin/bash

set -o pipefail # prevents errors in a pipeline from being masked. If any command in a pipeline fails, that return code will be used as the return code of the whole pipeline.
set -o nounset  # exit when your script tries to use undeclared variables.

function echoUsage() {
    echo "usage: $(basename $0) <xsd> <xml-dir>" >&2
    echo "This script validates xml files found in given directory and produces an xmllint output file"
    echo "Params:"
    echo " <xsd> xml schema of a nextprot entry"
    echo " <xml-dir> directory where xml files to validate are located"
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
validation_file="xmllint"_with_$(basename ${xsd})

pushd ${dir} > /dev/null
echo "-- searching xml files in directory '${dir}' ..."
entries=`find . -type f \( -iname "*.xml" \)`

echo -n "-- running xmllint on files "${entries}...
xmllint --noout --timing --stream --schema ${xsd} ${entries} 2> ${validation_file}.out
echo " done"

grep -v validate ${validation_file}.out | grep ':' | cut -d: -f3-6|sort|uniq > ${validation_file}.err

if [ -s ${validation_file}.err ]; then
  echo "[validation failed]: error in file '${validation_file}.err'"  >&2
  exit 2
else
  echo "[validation succeed]: output in file '${validation_file}.out'"
fi

popd > /dev/null
