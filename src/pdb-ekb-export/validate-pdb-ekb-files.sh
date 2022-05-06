#!/bin/bash

echo "Start PDB-eKB file validation in $1" > $2
find $1/ -type f -name '*.json' -print0 | while read -d $'\0' file; do
    echo "Processing $file" >> $2
    python3.6 funpdbe-validator/np_validator.py $file >> $2
    #exit
done
echo "End of validation" >> $2

