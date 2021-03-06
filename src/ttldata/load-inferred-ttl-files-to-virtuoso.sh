#!/bin/sh
sparql=" -X POST http://localhost:8890/sparql --data-urlencode 'output=ttl'  --data-urlencode 'query="
curl=$(which curl)


PREFIX="PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX dc: <http://purl.org/dc/elements/1.1/>
PREFIX dcterms: <http://purl.org/dc/terms/>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX sim: <http://purl.org/ontology/similarity/>
PREFIX mo: <http://purl.org/ontology/mo/>
PREFIX ov: <http://open.vocab.org/terms/>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX : <http://nextprot.org/rdf#>
PREFIX entry: <http://nextprot.org/rdf/entry/>
PREFIX isoform: <http://nextprot.org/rdf/isoform/>
PREFIX annotation: <http://nextprot.org/rdf/annotation/>
PREFIX evidence: <http://nextprot.org/rdf/evidence/>
PREFIX xref: <http://nextprot.org/rdf/xref/>
PREFIX publication: <http://nextprot.org/rdf/publication/>
PREFIX cv: <http://nextprot.org/rdf/terminology/>
PREFIX gene: <http://nextprot.org/rdf/gene/>
PREFIX source: <http://nextprot.org/rdf/source/>
PREFIX db: <http://nextprot.org/rdf/db/>
PREFIX context: <http://nextprot.org/rdf/context/>
"
for file in /work/ttldata/construct.d/*.sparql; do
  CONSTRUCT=$(cat $file)
  BASENAME=$(basename "$file" .sparql)
#  QUERY=$(echo "'exec=SPARQL  $PREFIX $CONSTRUCT;'"|tr '\n' ' ') 
  echo "---- create construct/$BASENAME.ttl inference"
#  EXEC="$curl $sparql $PREFIX $CONSTRUCT'"
#  sh -c "isql 1111 dba dba VERBOSE=OFF BANNER=OFF ${QUERY}" > /work/ttldata/nobackup/construct/$BASENAME.ttl
  sh -c "$curl $sparql $PREFIX $CONSTRUCT'"> /work/ttldata/nobackup/construct/$BASENAME.ttl
#  echo "$curl $sparql $PREFIX $CONSTRUCT'"
done

echo "register turtle files to be loaded..."
#isql 1111 dba dba exec="delete from DB.DBA.load_list;"
isql 1111 dba dba exec="ld_dir ('/work/ttldata/nobackup/construct', '*.ttl', 'http://nextprot.org/rdf') ;"
isql 1111 dba dba exec="rdf_loader_run();"
isql 1111 dba dba exec="checkpoint;"

# compute status of operations
fil_cnt=$(isql 1111 dba dba exec="select ll_file,ll_error from DB.DBA.load_list;" | grep construct | wc -l)
err_cnt=$(isql 1111 dba dba exec="select ll_file,ll_error from DB.DBA.load_list;" | grep construct | grep -v NULL | wc -l)
status=OK
details=""
if [ "$fil_cnt" != "7" ]; then status=ERROR ; details="Number for files loaded incorrect" ; fi
if [ "$err_cnt" != "0" ]; then status=ERROR ; details="Some files could not be loaded properly"; fi
echo "--------------------------------------------------------------------"
echo "Load status: $status $details" 
echo "--------------------------------------------------------------------"
if [ "$status" == "ERROR" ]; then
  isql 1111 dba dba exec="select ll_file,ll_error from DB.DBA.load_list;" | grep construct
fi

echo ""
echo "---------"
echo "END"
echo "---------"
echo ""


