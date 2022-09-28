#
# 1. Generate schema.ttl from local API
#

wget -O schema.ttl http://localhost:8080/nextprot-api-web/rdf/schema.ttl

#
# 2. Remove useless entities and update entity labels and comments
#    WARNING: ~/Downloads should contain an export of the google file
#

python3 reimport-nextprot-rdf-entities-descriptions.py
mv schema-new.ttl schema.ttl

#
# 3. Generate the HTML file describing the model
#

python3 pylode/pyLODE-2.13.2/pylode/cli.py -i ./schema.ttl  > schema.html

#
# 4. Fix pylode links
#

python3 fix-pylode-links.py
mv schema-fixed.html schema.html

sed 's/"#Protein"/"#Entry"/g' schema.html > schema-fixed.html
mv schema-fixed.html schema.html
sed 's/id="Protein"/id="Entry"/g' schema.html > schema-fixed.html
mv schema-fixed.html schema.html

#
# 5. Insert images in HTML schema
#

python3 insert_images.py
mv schema-images.html schema.html

#
# 6. Make alpha versions of html and ttl
#

./make-alpha.sh

ls -ltr








