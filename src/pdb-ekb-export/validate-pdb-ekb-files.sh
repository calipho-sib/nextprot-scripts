#!/bin/bash

find /home/npteam/pdb-ekb-parser/$1/ -type f -print0 | while read -d $'\0' file; do
    #echo "Processing $file"
    python3.6 funpdbe-validator/np_validator.py $file
done

