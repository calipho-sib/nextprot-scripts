#!/bin/sh

###isql 1111 dba dba exec="SPARQL DROP SILENT GRAPH <http://nextprot.org/rdf>;"

if pgrep virtuoso-t; then
  echo "killing virtuoso and wait 10 seconds..."
  kill $(pgrep virtuoso-t)
  sleep 10
else
  echo "virtuoso not running"
fi

echo "removing virtuoso data but saving virtuoso.ini"
mkdir -p /var/lib/virtuoso/tmp
cp /var/lib/virtuoso/db/virtuoso.ini /var/lib/virtuoso/tmp
rm /var/lib/virtuoso/db/*
cp /var/lib/virtuoso/tmp/virtuoso.ini /var/lib/virtuoso/db

echo "restarting viruoso and wait 30 seconds..."
/usr/bin/virtuoso-t +configfile /var/lib/virtuoso/db/virtuoso.ini --wait
# do not try to sleep less, virtuoso needs some time before isql sessions can start...
sleep 30

echo "setting some configuaration options"
isql 1111 dba dba exec="grant select on \"DB.DBA.SPARQL_SINV_2\" to \"SPARQL\";"
isql 1111 dba dba exec="grant execute on \"DB.DBA.SPARQL_SINV_IMP\" to \"SPARQL\";"
# For federated queries
isql 1111 dba dba exec="GRANT SPARQL_SPONGE TO \"SPARQL\";"
isql 1111 dba dba exec="GRANT EXECUTE ON DB.DBA.L_O_LOOK TO \"SPARQL\";"

echo "register turtle files to be loaded..."
isql 1111 dba dba exec="delete from DB.DBA.load_list;"
#isql 1111 dba dba exec="ld_dir ('/work/ttldata/construct', '*.ttl', 'http://nextprot.org/rdf') ;"
isql 1111 dba dba exec="ld_dir ('/work/ttldata/chromosome-new', '*.ttl', 'http://nextprot.org/rdf') ;"
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
sleep 600
isql 1111 dba dba exec="checkpoint;" 
# script below run independently
# sh ./load-virtuoso-inferences
echo "finshed at $(date)"


