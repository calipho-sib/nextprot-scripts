#!/bin/sh

###isql 1111 dba dba exec="SPARQL DROP SILENT GRAPH <http://nextprot.org/rdf>;"

/work/ttldata/stop-virtuoso.sh

echo "removing virtuoso data but saving virtuoso.ini"
mkdir -p /var/lib/virtuoso/tmp
cp /var/lib/virtuoso/db/virtuoso.ini /var/lib/virtuoso/tmp
rm /var/lib/virtuoso/db/*
cp /var/lib/virtuoso/tmp/virtuoso.ini /var/lib/virtuoso/db

/work/ttldata/restart-virtuoso

echo "setting some configuaration options"
isql 1111 dba dba exec="grant select on \"DB.DBA.SPARQL_SINV_2\" to \"SPARQL\";"
isql 1111 dba dba exec="grant execute on \"DB.DBA.SPARQL_SINV_IMP\" to \"SPARQL\";"
# For federated queries
isql 1111 dba dba exec="GRANT SPARQL_SPONGE TO \"SPARQL\";"
isql 1111 dba dba exec="GRANT EXECUTE ON DB.DBA.L_O_LOOK TO \"SPARQL\";"

echo "register turtle files to be loaded..."
isql 1111 dba dba exec="delete from DB.DBA.load_list;"
#isql 1111 dba dba exec="ld_dir ('/work/ttldata/nobackup/construct', '*.ttl', 'http://nextprot.org/rdf') ;"
isql 1111 dba dba exec="ld_dir ('/work/ttldata/nobackup/export-ttl', '*.ttl', 'http://nextprot.org/rdf') ;"
#isql 1111 dba dba exec="select * from DB.DBA.load_list;"
#isql 1111 dba dba exec="rdf_loader_run();"

echo "now load them using multiple processes in parallel"
isql 1111 dba dba exec="rdf_loader_run();" & 
isql 1111 dba dba exec="rdf_loader_run();" & 
isql 1111 dba dba exec="rdf_loader_run();" & 
isql 1111 dba dba exec="rdf_loader_run();" & 
isql 1111 dba dba exec="rdf_loader_run();" & 
isql 1111 dba dba exec="rdf_loader_run();" & 
isql 1111 dba dba exec="rdf_loader_run();" &  
isql 1111 dba dba exec="rdf_loader_run();" &
wait 
echo "waiting for virtuoso index, 10 minutes"

# check load and print status 
fil_cnt=$(isql 1111 dba dba exec="select ll_file,ll_error from DB.DBA.load_list;" | grep export-ttl | wc -l)
err_cnt=$(isql 1111 dba dba exec="select ll_file,ll_error from DB.DBA.load_list;" | grep export-ttl | grep -v NULL | wc -l)
status=OK
details=""
if [ "$fil_cnt" != "30" ]; then status=ERROR ; details="Number for files loaded incorrect" ; fi
if [ "$err_cnt" != "0" ]; then status=ERROR ; details="Some files could not be loaded properly"; fi
echo "--------------------------------------------------------------------"
echo "Load status: $status $details" 
echo "--------------------------------------------------------------------"
if [ "$status" == "ERROR" ]; then
  isql 1111 dba dba exec="select ll_file,ll_error from DB.DBA.load_list;" | grep chromosome
fi

sleep 600
isql 1111 dba dba exec="checkpoint;"

echo ""
echo "------------------------------"
echo "finshed at $(date)"
echo "------------------------------"
echo ""



