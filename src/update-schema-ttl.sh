shopt -s expand_aliases

last_dir=$(pwd)
cd 
cd nextprot-scripts/src/polish-rdf
wget -O schema.ttl http://localhost:8080/nextprot-api-web/rdf/schema.ttl
python3 reimport-nextprot-rdf-entities-descriptions.py
cp schema-new.ttl /work/ttldata/export-ttl/schema.ttl
cd $last_dir
