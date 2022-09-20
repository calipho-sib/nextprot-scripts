import rdflib
from rdflib import URIRef, Literal
from rdflib.namespace import Namespace
from rdflib.namespace import XSD
import sys


# input file with possibly new labels and new comments
goofiles= [
    "/Users/pmichel/Downloads/nextprot-rdf-classes - nextprot-rdf-classes-V2.tsv",
    "/Users/pmichel/Downloads/nextprot-rdf-classes - nextprot-rdf-predicates.tsv",
    "/Users/pmichel/Downloads/nextprot-rdf-classes - nextprot-named-individuals.tsv"
    ]

# input file with current schema in ttl format
ttlfile="schema.ttl"

# output file
new_ttlfile = "schema-new.ttl"

# load graph from current schema.ttl file
print("### Reading and loading current graph schema", ttlfile)
g = rdflib.Graph()
g.parse(ttlfile)
print("### Graph triple count before changes", len(g))

# save initial step
step=0
g.serialize(destination = "schema-tmp." + str(step))

for goofile in goofiles:
    step += 1
    # get changes from google doc sheet TAB
    print("### Reading changes to do in file", goofile)
    entities_to_hide = set()
    entities_to_change = dict()
    f_in=open(goofile)
    line_no=0
    while True:
        line = f_in.readline()
        if line == "": break
        line_no += 1
        # skip lines not related to a specific class URI
        if not line.startswith("http://nextprot.org/rdf"): continue
        fields = line.split("\t")
        uri = fields[0].strip()
        name = fields[1].strip()
        status = fields[2].strip()
        label = fields[3].strip()
        new_label = fields[4].strip()
        comment = fields[5].strip()
        new_comment = fields[6].strip()

        # entities we will remove from the schema
        if status.lower().strip()== "private":
            entities_to_hide.add(uri)

        # check the current uri appears as a subject in the graph
        else:
            rows = g.query("select (count(*) as ?cnt) where { <" + uri + "> ?p ?o. }")
            cnt = 0
            for r in rows: cnt = int(r.cnt)
            # unknown entities we should not have in the goo files
            if cnt == 0:
                print("### Unknown uri", uri)
            # entities to be updated    
            else:
                record = {"uri": uri, "name": name , "label": label,
                      "new_label": new_label, "comment": comment, "new_comment": new_comment }
                entities_to_change[uri] = record
        
    f_in.close()

    # for debug only
    if 1==2:        
        print("\n### Entities to hide\n")
        for k in entities_to_hide: print(k)
        print("\n### Entities to consider for modification\n")
        for k in entities_to_change: print(entities_to_change[k])

    # remove entities that should not appear in ontology
    for k in entities_to_hide:
        print("### Removing any triple related to", k)
        g.remove((URIRef(k), None, None))
        g.remove((None, None, URIRef(k)))
    print("### Graph triple after removals", len(g))

    # update label and comments according to content of google doc
    for k in entities_to_change:
        record = entities_to_change[k]
        g.remove((URIRef(k), URIRef("http://www.w3.org/2000/01/rdf-schema#label"), None))
        g.remove((URIRef(k), URIRef("http://www.w3.org/2000/01/rdf-schema#comment"), None))
        label = record.get("label")
        new_label = record.get("new_label")
        if label != new_label: print("### Label change in google doc", k, label, "=>", new_label)
        if new_label is not None and len(new_label)>0:
            g.add((URIRef(k), URIRef("http://www.w3.org/2000/01/rdf-schema#label"), Literal(new_label, datatype=XSD.string)))
        comment = record.get("comment")
        new_comment = record.get("new_comment")
        if comment != new_comment: print("### Comment change in google doc", k , comment, "=>", new_comment)
        if new_comment is not None and len(new_comment)>0:
            g.add((URIRef(k), URIRef("http://www.w3.org/2000/01/rdf-schema#comment"), Literal(new_comment, datatype=XSD.string)))
    print("### Graph triple after all changes", len(g))

    g.serialize(destination = "schema-tmp." + str(step))

# now save new schame in a new file
print("### Saving modified schema", new_ttlfile)
g.serialize(destination = new_ttlfile)

print("### end")

