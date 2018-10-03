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
infiles="1 2 3 4 5 6 7 8 9 0 10 11 12 13 14 15 16 17 18 19 20 21 22 X Y MT unknown nextprot_all"
#infiles="Y MT"

global_result=0
for item in $infiles; do
  xml=$dir/$item.xml
  echo --------------------------------------------------------------------------------------------------------------------------------------
  echo Validating $xml with schema $xsd  
  echo --------------------------------------------------------------------------------------------------------------------------------------
  xmllint --noout --schema $xsd $xml
  result=$?
  let "global_result += $result"
  if [ "$result" = "0" ]; then
    echo Summary: Validation of $xml status: OK
  else
    echo Summary: Validation of $xml status: ERROR
  fi
done

echo --------------------------------
if [ "$global_result" = "0" ]; then
  echo Summary: Global validation status: OK
else
  echo Summary: Global validation status: ERROR
fi
echo --------------------------------
