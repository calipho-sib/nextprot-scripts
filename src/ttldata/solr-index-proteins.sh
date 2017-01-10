indexname=entries
#indexname=gold-entries
urlbase="http://localhost:8080/nextprot-api-web"
chromosomes="1 2 3 4 5 6 7 8 9 0 10 11 12 13 14 15 16 17 18 19 20 21 22 MT X Y unknown"
wget -O /work/ttldata/operations/tasks-solr-entries-init.log ${urlbase}/tasks/solr/${indexname}/init
for chrname in $chromosomes
do
  logfile="/work/ttldata/operations/tasks-solr-${indexname}-${chrname}.log"
  url="${urlbase}/tasks/solr/${indexname}/index/chromosome/${chrname}"
  wget --timeout=7200 -O $logfile "$url"
done

