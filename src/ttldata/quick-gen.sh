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

function publishFtp() {

  # check that we have a touch date for the ftp release files and directories
  if [ "$touchdate" = "" ] ; then
  	echo $(date) - ERROR: no touch date defined for ftp release
  	echo $(date) - All actions cancelled
    exit 1
  fi 
  
  # skip archiving if explicitly specified in argument 1
  if [ "$1" = "skip-archive" ] ; then
  	echo $(date) - Skipped archiving of previous release
  else
  	echo $(date) - Archiving of previous release
  	archiveFtp
  fi 
  
  # publish
  # some variables used in there are defined at the top of the main program
  # target_dir=$ftp_root/previous_releases/test # value used for testing
  target_dir=$ftp_root/current_release
  ssh $ftp_server mkdir -p $target_dir
  ssh $ftp_server rm -rf $target_dir/*
  scp -r $pre_ftp_dir/* $ftp_server:$target_dir
  ssh $ftp_server touch -t${touchdate}0200 $target_dir
  ssh $ftp_server "find $target_dir -name '*' -exec touch -t${touchdate}0200 {} \;"
  ssh $ftp_server "cp -pf $target_dir/README $target_dir/../README ; cp -pf $target_dir/README $target_dir/../../README"
   
}

function archiveFtp() {
  
  # get date of current release
  dt=$(ssh $ftp_server "stat -c %y $ftp_root/current_release | cut -d' ' -f1")
  echo $(date) - Current release $dt on ftp server will be archived

  # build name for tar file
  tarname=/local/ftpnextprot/root/pub/previous_releases/nextprot_release_$dt.tar
  ssh $ftp_server "test -e $tarname"
  tar_exists=$?
  # 0 means, yes, it exists !!!
  # if file exists we don't want to erase it so we create a unique name for the tar file...
  if (( $tar_exists == 0 )); then
    echo  $(date) - Tar file exists !
    postfix=$(date +%Y%m%d.%H%M)
    tarname=/local/ftpnextprot/root/pub/previous_releases/nextprot_release_$dt.created_at_$postfix.tar
  fi
  
  # archive files of current release in the tar file
  ssh $ftp_server "cd $ftp_root/current_release; tar cf $tarname ."

}

function prepareFtp() {

  datadir=/work/ttldata

  # clean directory
  mkdir -p $pre_ftp_dir
  rm -rf $pre_ftp_dir/*

  # get latest README for ftp 
  curl 'https://raw.githubusercontent.com/calipho-sib/nextprot-readme/master/README' -o $pre_ftp_dir/README

  # collect data generated earlier by NP2 API for further puplication on ftp server
  subdirs="ac_lists chr_reports hpp_reports md5 peff ttl-compressed xml-compressed"
  for subdir in $subdirs; do
    echo copying content of $datadir/$subdir ...
    cp -rL $datadir/$subdir $pre_ftp_dir/
  done
 
  # move xml to final directory name
  mv $pre_ftp_dir/xml-compressed $pre_ftp_dir/xml
  
  # move ttl to final directory name
  mkdir -p $pre_ftp_dir/rdf
  mv $pre_ftp_dir/ttl-compressed $pre_ftp_dir/rdf/ttl
 
  # move hpp_reports to final directory name and add dedicated HPP_README.txt
  mkdir -p $pre_ftp_dir/custom
  mv $pre_ftp_dir/hpp_reports $pre_ftp_dir/custom/hpp
  curl 'https://raw.githubusercontent.com/calipho-sib/nextprot-readme/master/HPP_README.txt' -o $pre_ftp_dir/custom/hpp/HPP_README.txt

  # collect data generated earlier with NP1 ant tasks for further publication on ftp server
   
  # copy of NP1 controlled vocabularies
  cvdirs=/mnt/npdata/proxy/cvterms/
  latest=$(ls -1tr $cvdirs | grep 201 | tail -n1)
  indir=$cvdirs/$latest
  outdir=$pre_ftp_dir/controlled_vocabularies
  mkdir -p $outdir
  echo copying content of $indir ...
  cp $indir/cv-uniprot-tissue.proxied $outdir/caloha.obo    
  cp $indir/cv-uniprot-domain.proxied $outdir/cv_domain.txt    
  cp $indir/cv-nextprot-family.proxied $outdir/cv_family.txt    
  cp $indir/cv-uniprot-metal.proxied $outdir/cv_metal.txt    
  cp $indir/cv-nextprot-modification-effect.proxied $outdir/cv_modification_effect.obo    
  cp $indir/cv-nextprot-protein-property.proxied $outdir/cv_protein_property.obo    
  cp $indir/cv-uniprot-topology.proxied $outdir/cv_topological_domain.txt    
  cp $indir/cv-icepo.proxied $outdir/icepo.obo    
  cp /share/sib/common/Calipho/np/cv/Caloha_readme.txt $outdir  

  # copy of NP1 mapping directory
  indir=/mnt/npdata/export/mapping/
  outdir=$pre_ftp_dir/mapping
  mkdir -p $outdir
  echo copying content of $indir ...
  cp $indir/*.txt $outdir/   

 
  # copy all directories except ttl & xml to M for QC
  qcdir=/share/sib/common/Calipho/np/FTP/current
  mkdir -p $qcdir
  rm -rf $qcdir/*
  subdirs="ac_lists chr_reports controlled_vocabularies custom mapping md5 peff" 
  cp $pre_ftp_dir/README $qcdir
  for subdir in $subdirs; do
    echo copying content of $pre_ftp_dir/$subdir for QC to $qcdir ...
    cp -rL $pre_ftp_dir/$subdir $qcdir/
  done
  
}

function acLists() {

  mkdir -p /work/ttldata/ac_lists
  rm -rf /work/ttldata/ac_lists/*

  logfile="generate-ac-lists-$(date "+%Y%m%d-%H%M").log"

  url="${apibase}/entry-accessions.txt"
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

function isoMd5() {
  logfile="generate-iso-md5s-$(date "+%Y%m%d-%H%M").log"
  mkdir -p /work/ttldata/md5
  rm -rf /work/ttldata/md5/*
  url="${apibase}/isoforms.tsv"
  outfile=/work/ttldata/md5/nextprot_sequence_md5.txt
  wget --timeout=7200 --output-document=$outfile "$url" >> $logfile 2>&1
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
  url="${apibase}/export/entries/all.peff"
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

function compressPeff() {

	tdate=$1
	peffgz_dir= /work/ttldata/peff-compressed
    mkdir -p $peffgz_dir
	rm -rf $peffgz_dir/*
	cp /work/ttldata/peff/*  $peffgz_dir/
	touch -t$tdate $peffgz_dir/* 
	gzip $peffgz_dir/*
	touch -t$tdate $peffgz_dir/*

}


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
# main program
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

apibase="http://localhost:8080/nextprot-api-web"
ftp_server=pmichel@ftp.nextprot.org
ftp_root=/local/ftpnextprot/root/pub
pre_ftp_dir=/work/ttldata/nobackup/prepared_ftp

actions=$1
touchdate=$2

if [ "$actions" = "" ] ; then
  echo " "
  echo "To be run on BUILD platform, currently kant"
  echo " "
  echo Usage $0 \"action1 ... actionN\" [MMdd]
  echo " "
  echo "  where actions is a space separated list of items"
  echo "  and MMdd is a month/date used to touch xml and ttl files when gz or publish-ftp"
  echo "  action is in action list."
  echo " "
  echo "Action items"
  echo " "
  echo "- cache:" 
  echo "  builds the API cache for all entries and stats"
  echo " "
  echo "- ttl:"
  echo "  builds the RDF turtle files, store them in directory export-ttl, load them in"
  echo "  virtuoso, check files content consistency" 
  echo " "
  echo "- rdfhelp:"
  echo "  builds the RDF help based on SPARQL queries run by the API, depends on content"
  echo "  generated by ttl action" 
  echo " "
  echo "- xml:" 
  echo "  builds the XML files, store them in directory export-xml, check files content "
  echo "  consistency"
  echo " "
  echo "- solr:" 
  echo "  builds the 4 solr indexes used by the API simple search system" 
  echo "- solr-publi:"
  echo "  builds the solr index used for the API simple search system for publications" 
  echo "- solr-term:"
  echo "  builds the solr index used for the API simple search system for terms" 
  echo "- solr-entries:"
  echo "  builds the solr index used for the API simple search system for entries" 
  echo "- solr-gold-entries:"
  echo "  builds the solr index used for the API simple search system for entries taking into"
  echo "  account only gold content" 
  echo " "
  echo "- gz:"
  echo "  touches the xml and ttl files with the given date and then compress them individually"
  echo "  and store them in xml-compressed and ttl-compressed directories" 
  echo " "
  echo "- runrq:"
  echo "  runs all the tutorial SPARQL queries and stores the result in a tsv tile" 
  echo " "
  echo "- chr-reports: "
  echo "  generates the chromosome reports and store them in directory chr_reports" 
  echo "- hpp-reports:"
  echo "  generates the hpp chromosome reports and store them in directory hpp_reports" 
  echo "- ac-lists:"
  echo "  generates the accession list files and store them in directory ac_lists" 
  echo "- peff:"
  echo "  generates the peff files and store them in directory peff" 
  echo "- iso-md5:"
  echo "  generates the isoform md5 file and store it in directory md5" 
  echo " "
  echo "- prepare-ftp:"
  echo "  collects files generated by actions gz chr-reports hpp-reports ac-lists -iso-md5 peff"
  echo "  iso-md5 plus NP1 controlled_vocabularies and mapping directories in a new directory "
  echo "  prepared_ftp, note that a copy (except xml and ttl files) is also copied to M: for "
  echo "  QC purpose" 
  echo "- archive-ftp:"
  echo "  archive the content of the current release directory of the ftp server in directory"
  echo "  previous-releases, the name of the tar is based on the modification date of "
  echo "  current_release directory" 
  echo "- publish-ftp:"
  echo "  performs the archive-ftp action and then publish the content of directory "
  echo "  prepared-ftp to ftp server on current_release directory. All files on ftp server are"
  echo "  touched with date chosen by user" 
  echo "- publish-ftp-skip-archive:"
  echo "  same as publish-ftp but skipy the archiving of previous-relese so USE WITH CARE" 
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

# generate isoform MD5 file
  if [ "$action" = "iso-md5" ] ; then
    isoMd5
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


# compress peff files

  if [ "$action" = "gz-peff" ] ; then

	compressPeff ${touchdate}0200
    
  fi


# prepare content for ftp
  if [ "$action" = "prepare-ftp" ] ; then
    prepareFtp
  fi

# archive current ftp release
  if [ "$action" = "archive-ftp" ] ; then
    archiveFtp
  fi

# publish current ftp release
  if [ "$action" = "publish-ftp" ] ; then
    publishFtp
  fi

# publish current ftp release without archiving previous release
  if [ "$action" = "publish-ftp-skip-archive" ] ; then
    publishFtp skip-archive
  fi



done
echo $(date) - Finished


