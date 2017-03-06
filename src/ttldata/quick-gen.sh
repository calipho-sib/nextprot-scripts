#!/bin/bash

actions=$1
touchdate=$2

if [ "$actions" = "" ] ; then
  echo " "
  echo Usage $0 \"action1 ... actionN\" [MMdd]
  echo " "
  echo where actions is a space separated list ot these possible items: \"cache ttl xml solr gz rdfhelp runrq\"
  echo and MMdd is a month/date used to touch xml and ttl files when gz action is in action list. 
  echo " "
  exit 1
fi

echo $(date) - Starting $0 with actions=[$1] and optional touchdate=[$2]

echo $(date) - Updating local nextprot-scripts 

cd ~/nextprot-scripts
git pull

mkdir -p /work/ttldata/operations


for action in $actions; do

  echo $(date) - Starting action $action
  cd /work/ttldata/operations


# generate cache

  if [ "$action" = "cache" ] ; then
    nohup nxs-generate-api-cache-by-entry.py build-api.nextprot.org < /dev/null > nxs-generate-api-cache-by-entry-$(date "+%Y%m%d-%H%M").log 2>&1
  fi

# generate cache for rdfhelp (to be run after ttl are generated and loaded) 

  if [ "$action" = "rdfhelp" ] ; then
    urlbase="http://localhost:8080/nextprot-api-web"
    wget --timeout=7200 --output-document=rdfhelp-$(date "+%Y%m%d-%H%M").json "$urlbase/rdf/help/type/all.json"
  fi


# run the list of SPARQL tutorial queries 

  if [ "$action" = "runrq" ] ; then
    urlbase="http://localhost:8080/nextprot-api-web"
    wget --timeout=7200 --output-document=run-sparql-queries-$(date "+%Y%m%d-%H%M").tsv "$urlbase/run/query/direct/tags/tutorial"
  fi




# generate ttl

  if [ "$action" = "ttl" ] ; then
    rm -rf /work/ttldata/nobackup/export-ttl/*
    rm -rf /work/construct/*.ttl
    rm -rf /work/ttldata/nobackup/ttl-compressed/*
    nohup nxs-export-by-chromosome.py -t1 build-api.nextprot.org ttl /work/ttldata/nobackup/export-ttl > nxs-export-by-chromosome-ttl-$(date "+%Y%m%d-%H%M").log 2>&1
    nohup /work/ttldata/check-base-ttl-files.sh > check-base-ttl-files-$(date "+%Y%m%d-%H%M").log 2>&1 
    nohup /work/ttldata/generate-inferred-ttl-files-from-fuseki.sh> generate-inferred-ttl-files-from-fuseki-$(date "+%Y%m%d-%H%M").log 2>&1
    nohup /work/ttldata/load-base-ttl-files-to-virtuoso.sh > load-base-ttl-files-to-virtuoso-$(date "+%Y%m%d-%H%M").log 2>&1
    nohup /work/ttldata/load-inferred-ttl-files-to-virtuoso.sh > load-inferred-ttl-files-to-virtuoso-$(date "+%Y%m%d-%H%M").log 2>&1
  fi


# generate xml

  if [ "$action" = "xml" ] ; then
    rm -rf /work/ttldata/nobackup/export-xml/*
    rm -rf /work/ttldata/nobackup/xml-compressed/*
    nohup nxs-export-by-chromosome.py -t1 build-api.nextprot.org xml /work/ttldata/nobackup/export-xml > nxs-export-by-chromosome-xml-$(date "+%Y%m%d-%H%M").log 2>&1
    nohup wget --output-document=/work/ttldata/export-xml/nextprot_all.xml http://localhost:8080/nextprot-api-web/export/entries/all.xml
    nohup wget --output-document=/work/ttldata/export-xml/nextprot-export-v2.xsd http://build-api.nextprot.org/nextprot-export-v2.xsd
    nohup /work/ttldata/check-xml-files.sh > check-xml-files-$(date "+%Y%m%d-%H%M").log
    nohup nxs-validate-all-xml.sh /work/ttldata/nobackup/export-xml/nextprot-export-v2.xsd /work/ttldata/nobackup/export-xml/ > nxs-validate-all-xml-$(date "+%Y%m%d-%H%M").log 2>&1 
  fi


# update solr schemas
# ... right place to do it ?...

# generate solr indices

  if [ "$action" = "solr" ] ; then
    urlbase="http://localhost:8080/nextprot-api-web"
    chromosomes="1 2 3 4 5 6 7 8 9 0 10 11 12 13 14 15 16 17 18 19 20 21 22 MT X Y unknown"

    wget --timeout=7200 --output-document=tasks-solr-terminologies-reindex-$(date "+%Y%m%d-%H%M").log "$urlbase/tasks/solr/terminologies/reindex"

    wget --timeout=7200 --output-document=tasks-solr-publications-reindex-$(date "+%Y%m%d-%H%M").log "$urlbase/tasks/solr/publications/reindex"

    indexname=entries
    wget --timeout=7200 --output-document=tasks-solr-entries-init-$(date "+%Y%m%d-%H%M").log ${urlbase}/tasks/solr/${indexname}/init
    for chrname in $chromosomes; do
      logfile="tasks-solr-${indexname}-${chrname}-$(date "+%Y%m%d-%H%M").log"
      url="${urlbase}/tasks/solr/${indexname}/index/chromosome/${chrname}"
      wget --timeout=7200 --output-document=$logfile "$url"
    done

    indexname=gold-entries
    wget --timeout=7200 --output-document=tasks-solr-entries-init-$(date "+%Y%m%d-%H%M").log ${urlbase}/tasks/solr/${indexname}/init
    for chrname in $chromosomes; do
      logfile="tasks-solr-${indexname}-${chrname}-$(date "+%Y%m%d-%H%M").log"
      url="${urlbase}/tasks/solr/${indexname}/index/chromosome/${chrname}"
      wget --timeout=7200 --output-document=$logfile "$url"
    done
  fi


# prepare xml & ttl for ftp: compress, rename & touch

  if [ "$action" = "gz" ] ; then
    nohup /work/ttldata/compress-and-rename-xml-files.sh 12020200 > compress-and-rename-xml-files-$(date "+%Y%m%d-%H%M").log 2>&1 
    nohup /work/ttldata/compress-and-rename-ttl-files.sh 12020200 > compress-and-rename-ttl-files-$(date "+%Y%m%d-%H%M").log 2>&1
  fi


done
echo $(date) - Finished

