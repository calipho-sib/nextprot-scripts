#!/bin/bash

INPUT_FOLDER=$1
OUTPUT_FOLDER=$2

if [[ ! -e $OUTPUT_FOLDER ]]; then
    mkdir $OUTPUT_FOLDER
fi

echo "Start copying validated files..."
filenames=$(grep 'passed index validation' $INPUT_FOLDER | cut -f 3 -d ' ' )
while read line ; do
    subfolder=`echo $line | cut -f 2 -d '/'`
    new_subfolder=$OUTPUT_FOLDER/$subfolder
    #echo "$line => $subfolder => $new_subfolder"
    if [[ ! -e $new_subfolder ]]; then
        mkdir $new_subfolder
    fi
    cp $line $new_subfolder/
done <<< "$filenames"
echo "End copying validated files."

