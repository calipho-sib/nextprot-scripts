#!/bin/bash

function echoUsage() {
	echo "---"
	echo ""
	echo "usage: $0 arg1 arg2"
	echo ""
	echo "arg1 specifies the target of the deployment"
	echo ""
	echo "arg1=build  : sync svn source to target solr server on kant  (build machine) "
	echo "arg1=dev    : sync svn source to target solr server on crick (dev machine) "
    echo "arg1=alpha  : sync svn source to target solr server on uat-web2 (alpha machine) "
	echo ""
	echo "arg2 specifies the action to perform"
	echo ""
	echo "arg2=diff   : show diff between source and target"
	echo "arg2=update : actually perform sync from source to target"
	echo ""
	echo "---"
}

if [ "$1" = "pam" ]; then
	SERVER_SOLR="/Users/pmichel/tools/solr-4.5.0/example/solr"
elif [ "$1" = "build" ]; then
	SERVER_SOLR="npteam@kant:/work/devtools/solr-4.5.0/example/solr"
elif [ "$1" = "dev" ]; then
        SERVER_SOLR="npteam@crick:/work/devtools/solr-4.5.0/example/solr"
elif [ "$1" = "alpha" ]; then
	SERVER_SOLR="npteam@uat-web2:/work/devtools/solr-4.5.0/example/solr"
else
	echoUsage
	exit 1
fi

if [ "$2" = "diff" ]; then
	OPT="-n -varcC"
elif [ "$2" = "update" ]; then
	OPT="-varcC"
else
	echoUsage
	exit 1
fi


NCS_DIR=~/tmp/nsc
SRC=$NCS_DIR/nextprot-solr-config


echo "target solr server: $SERVER_SOLR"
echo "action: $2"
echo "OPT=$OPT"
echo "SRC=$SRC"
echo "SERVER_SOLR=$SERVER_SOLR"


# get latest solr config version from github repository

mkdir -p $NCS_DIR
rm -rf $NCS_DIR/*
cd $NCS_DIR
git clone https://github.com/calipho-sib/nextprot-solr-config.git

set -v

# solrconfig.xml in each core
rsync $OPT $SRC/solrconfig.xml $SERVER_SOLR/npcvs1/conf/solrconfig.xml | grep -Ev "building|total|sent"
rsync $OPT $SRC/solrconfig.xml $SERVER_SOLR/nppublications1/conf/solrconfig.xml | grep -Ev "building|total|sent"
rsync $OPT $SRC/solrconfig.xml $SERVER_SOLR/npentries1/conf/solrconfig.xml | grep -Ev "building|total|sent"
rsync $OPT $SRC/solrconfig.xml $SERVER_SOLR/npentries1gold/conf/solrconfig.xml | grep -Ev "building|total|sent"
rsync $OPT $SRC/npcvs1/conf $SERVER_SOLR/npcvs1/ | grep -Ev "building|total|sent"
rsync $OPT $SRC/nppublications1/conf $SERVER_SOLR/nppublications1/ | grep -Ev "building|total|sent"
rsync $OPT $SRC/npentries1/conf $SERVER_SOLR/npentries1/ | grep -Ev "building|total|sent"
rsync $OPT $SRC/npentries1/conf $SERVER_SOLR/npentries1gold/ | grep -Ev "building|total|sent"



