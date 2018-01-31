#!/bin/bash

function solrPubli() {
  wget --timeout=7200 --output-document=tasks-solr-publications-reindex-$(date "+%Y%m%d-%H%M").log "${apibase}/tasks/solr/publications/reindex"
}

function solrTerm() {
  wget --timeout=7200 --output-document=tasks-solr-terminologies-reindex-$(date "+%Y%m%d-%H%M").log "${apibase}/tasks/solr/terminologies/reindex"
}

function solrEntries() {
  indexname=$1
  chromosomes="1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 MT X Y unknown"
  wget --timeout=7200 --output-document=tasks-solr-entries-init-$(date "+%Y%m%d-%H%M").log ${apibase}/tasks/solr/${indexname}/init
  for chrname in $chromosomes; do
    logfile="tasks-solr-${indexname}-${chrname}-$(date "+%Y%m%d-%H%M").log"
    url="${apibase}/tasks/solr/${indexname}/index/chromosome/${chrname}"
    wget --timeout=7200 --output-document=$logfile "$url"
  done
}


function acLists() {

  mkdir -p /work/ttldata/ac_lists
  rm -rf /work/ttldata/ac_lists/*

  logfile="generate-ac-lists-$(date "+%Y%m%d-%H%M").log"

  url="${apibase}/entry-accessions.json"
  outfile=/work/ttldata/ac_lists/nextprot_ac_list_all.txt
  wget --timeout=7200 --output-document=$outfile "$url" >> $logfile 2>&1

  chromosomes="1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 MT X Y unknown"
  logfile="generate-ac-lists-$(date "+%Y%m%d-%H%M").log"
  for chrname in $chromosomes; do
    url="${apibase}/entry-accessions/chromosome/${chrname}.txt"
    outfile=/work/ttldata/ac_lists/nextprot_ac_list_chromosome_${chrname}.txt
    wget --timeout=7200 --output-document=$outfile "$url" >> $logfile 2>&1
  done
  
  declare -a params=("PROTEIN_LEVEL" "TRANSCRIPT_LEVEL" "HOMOLOGY" "PREDICTED" "UNCERTAIN")
  declare -a names=("PE1_at_protein_level" "PE2_at_transcript_level" "PE3_homology" "PE4_predicted" "PE5_uncertain")
  lng=${#params[@]}
  for (( i=0; i<${lng}; i++ )); do
    url="${apibase}/entry-accessions/protein-existence/${params[$i]}.txt"
    outfile=/work/ttldata/ac_lists/nextprot_ac_list_${names[$i]}.txt
    wget --timeout=7200 --output-document=$outfile "$url" >> $logfile 2>&1
  done
  

}

function chrReports() {
  chromosomes="1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 MT X Y unknown"
  logfile="generate-chr-reports-$(date "+%Y%m%d-%H%M").log"
  mkdir -p /work/ttldata/chr_reports
  rm -rf /work/ttldata/chr_reports/*
  for chrname in $chromosomes; do
    url="${apibase}/chromosome-report/export/${chrname}"
    outfile=/work/ttldata/chr_reports/nextprot_chromosome_$chrname.txt
    wget --timeout=7200 --output-document=$outfile "$url" >> $logfile 2>&1
  done
}

function peffReports() {
  chromosomes="1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 MT X Y unknown"
  logfile="generate-peff-$(date "+%Y%m%d-%H%M").log"
  mkdir -p /work/ttldata/peff
  rm -rf /work/ttldata/peff/*
  for chrname in $chromosomes; do
    url="${apibase}/export/chromosome/${chrname}"
    outfile=/work/ttldata/peff/nextprot_chromosome_$chrname.peff
    wget --timeout=7200 --output-document=$outfile "$url" >> $logfile 2>&1
  done
  url="${apibase}/export/entries.peff?query=*"
  outfile=/work/ttldata/peff/nextprot_all.peff
  wget --timeout=7200 --output-document=$outfile "$url" >> $logfile 2>&1
}

function hppReports() {
  logfile="generate-hpp-reports-$(date "+%Y%m%d-%H%M").log"
  mkdir -p /work/ttldata/hpp_reports
  rm -rf /work/ttldata/hpp_reports/*

  url="${apibase}/chromosome-report/export/hpp/entry-count-by-pe.tsv"
  outfile=/work/ttldata/hpp_reports/count-of-pe12345-by-chromosome.txt
  wget --timeout=7200 --output-document=$outfile "$url" >> $logfile 2>&1

  url="${apibase}/chromosome-report/export/hpp/nacetylated-entries.tsv"
  outfile=/work/ttldata/hpp_reports/HPP_entries_with_nacetyl_by_chromosome.txt
  wget --timeout=7200 --output-document=$outfile "$url" >> $logfile 2>&1

  url="${apibase}/chromosome-report/export/hpp/phosphorylated-entries.tsv"
  outfile=/work/ttldata/hpp_reports/HPP_entries_with_phospho_by_chromosome.txt
  wget --timeout=7200 --output-document=$outfile "$url" >> $logfile 2>&1

  url="${apibase}/chromosome-report/export/hpp/unconfirmed-ms-data-entries"
  outfile=/work/ttldata/hpp_reports/HPP_entries_with_unconfirmed_MS_data.txt
  wget --timeout=7200 --output-document=$outfile "$url" >> $logfile 2>&1

  chromosomes="1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 MT X Y unknown"
  for chrname in $chromosomes; do
    url="${apibase}/chromosome-report/export/hpp/${chrname}.tsv"
    outfile=/work/ttldata/hpp_reports/HPP_chromosome_${chrname}.txt
    wget --timeout=7200 --output-document=$outfile "$url" >> $logfile 2>&1
  done
}

apibase="http://localhost:8080/nextprot-api-web"

actions=$1
touchdate=$2

if [ "$actions" = "" ] ; then
  echo " "
  echo Usage $0 \"action1 ... actionN\" [MMdd]
  echo " "
  echo where actions is a space separated list ot these possible items: \"cache ttl xml solr solr-publi solr-term solr-entries solr-gold-entries gz rdfhelp runrq chr-reports hpp-reports peff ac-lists\"
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
    wget --timeout=7200 --output-document=rdfhelp-$(date "+%Y%m%d-%H%M").json "${apibase}/rdf/help/type/all.json"
  fi


# run the list of SPARQL tutorial queries 

  if [ "$action" = "runrq" ] ; then
    wget --timeout=7200 --output-document=run-sparql-queries-$(date "+%Y%m%d-%H%M").tsv "${apibase}/run/query/direct/tags/tutorial"
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
    nohup wget --output-document=/work/ttldata/export-xml/nextprot_all.xml ${apibase}/export/entries/all.xml
    nohup wget --output-document=/work/ttldata/export-xml/nextprot-export-v2.xsd http://build-api.nextprot.org/nextprot-export-v2.xsd
    nohup /work/ttldata/check-xml-files.sh > check-xml-files-$(date "+%Y%m%d-%H%M").log
    nohup nxs-validate-all-xml.sh /work/ttldata/nobackup/export-xml/nextprot-export-v2.xsd /work/ttldata/nobackup/export-xml/ > nxs-validate-all-xml-$(date "+%Y%m%d-%H%M").log 2>&1 
  fi


# update solr schemas
# ... right place to do it ?...

# generate solr indices

  if [ "$action" = "solr" ] ; then
    solrTerm
    solrPubli
    solrEntries entries
    solrEntries gold-entries
  fi

  if [ "$action" = "solr-term" ] ; then
    solrTerm
  fi

  if [ "$action" = "solr-publi" ] ; then
    solrPubli
  fi

  if [ "$action" = "solr-entries" ] ; then
    solrEntries entries
  fi

  if [ "$action" = "solr-gold-entries" ] ; then
    solrEntries gold-entries
  fi

# generate peff files
  if [ "$action" = "peff" ] ; then
    peffReports
  fi

# generate chromosome reports
  if [ "$action" = "chr-reports" ] ; then
    chrReports
  fi

# generate AC lists
  if [ "$action" = "ac-lists" ] ; then
    acLists
  fi

# generate HPP reports
  if [ "$action" = "hpp-reports" ] ; then
    hppReports
  fi

# prepare xml & ttl for ftp: compress, rename & touch

  if [ "$action" = "gz" ] ; then
    
    nohup /work/ttldata/compress-and-rename-xml-files.sh ${touchdate}0200 > compress-and-rename-xml-files-$(date "+%Y%m%d-%H%M").log 2>&1 
    nohup /work/ttldata/compress-and-rename-ttl-files.sh ${touchdate}0200 > compress-and-rename-ttl-files-$(date "+%Y%m%d-%H%M").log 2>&1
  fi


done
echo $(date) - Finished


