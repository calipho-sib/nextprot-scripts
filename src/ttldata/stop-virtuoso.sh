#!/bin/sh

if pgrep virtuoso-t; then
  
  echo "$(date) virtuoso is running on $(hostname) ..."
  echo "$(date) requesting checkpoint..."
  isql 1111 dba dba exec="checkpoint;"

  echo "$(date) requesting shutdown..."
  isql 1111 dba dba exec="shutdown;"

  echo "$(date) virtuoso stopped on $(hostname)"

  sleep 5

else

  echo "$(date) virtuoso was not running on $(hostname)"
fi

