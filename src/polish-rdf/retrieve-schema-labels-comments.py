import rdflib
from rdflib import URIRef
from rdflib.namespace import Namespace
import sys

nx_namespace = Namespace('http://nextprot.org/rdf#')
db_namespace = Namespace('http://nextprot.org/rdf/db/')
src_namespace = Namespace('http://nextprot.org/rdf/source/')

g = rdflib.Graph()
g.parse("schema.ttl")

q = """
    PREFIX : <http://nextprot.org/rdf#> 
    PREFIX db: <http://nextprot.org/rdf/db/> 
    PREFIX source: <http://nextprot.org/rdf/source/> 
    PREFIX owl: <http://www.w3.org/2002/07/owl#> 
    PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> 
    PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#> 
    PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
    SELECT ?s ?label ?source_file  ?comment
    WHERE {
        ?s rdf:type owl:Class .
        optional {
            ?s :sourceFile ?source_file .
        }
        optional {
            ?s rdfs:label ?label .
        }
        optional {
            ?s rdfs:comment ?comment .
        }
    } order by ?s
"""

goo_dic = dict()
f_in = open("goodoc.in")
line_no=0
while True:
    line = f_in.readline()
    if line == "": break
    line_no+=1
    elems = line.split("\t")
    if len(elems) != 6:
        print("ERROR: unexpected col numbers at line", line_no)
        sys.exit()
    rec = {
        "uri" : elems[0].strip(),
        "name" : elems[1].strip(),
        "status" : elems[2].strip(),
        "comment" : elems[3].strip(),
        "curated_comment" : elems[4].strip(),
        "lydie" : elems[5].strip()}
    goo_dic[rec["name"]]=rec
    
f_in.close()

print("### All Google doc Classes merged with Classes in schema")
print(" ")
print("URI" + "\t" +"ClassName from RDFHelp" + "\t" +"status" + "\t" +"label" + "\t" +"suggested label" + "\t" +"comment" + "\t" +"suggested comment" + "\t" +"Lydie's comments")
for r in g.query(q):
    subject = r["s"]
    if subject in nx_namespace:
        name = subject[len(nx_namespace):]
        source_file = r["source_file"]
        if source_file is None: source_file = ""
        label = r["label"] 
        if label is None: label = ""
        comment = r["comment"]    
        if comment is None: comment = ""
        found = False
        curated_label = str(label)
        curated_comment = ""
        status = ""
        lydie = ""
        if name in goo_dic:
            goo_dic[name]["found"]=True
            found = True
            curated_comment = goo_dic[name]["curated_comment"]            
            status = goo_dic[name]["status"]
            lydie = goo_dic[name]["lydie"]            
        myline = ""
        myline += str(subject) + "\t" 
        myline += str(name) + "\t" 
        myline += status + "\t" 
        myline += str(label)+ "\t" 
        myline += curated_label + "\t" 
        myline += str(comment) + "\t" 
        myline += curated_comment + "\t"
        myline += lydie
        print(myline)

print(" ")
print("### Google doc items not included in new schema:")
for k in goo_dic:
    if not goo_dic[k].get("found"):
        print("#", k)


q = """
    PREFIX : <http://nextprot.org/rdf#> 
    PREFIX db: <http://nextprot.org/rdf/db/> 
    PREFIX source: <http://nextprot.org/rdf/source/> 
    PREFIX owl: <http://www.w3.org/2002/07/owl#> 
    PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> 
    PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#> 
    PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
    SELECT ?s ?label ?source_file  ?comment ?typ
    WHERE {
        ?s rdf:type ?typ .
        optional {
            ?s :sourceFile ?source_file .
        }
        optional {
            ?s rdfs:label ?label .
        }
        optional {
            ?s rdfs:comment ?comment .
        }
        #filter (?typ == rdf:Property)
    } order by ?s
"""

f_out = open("pred.tsv","w")
print("### Predicates in schema")
print(" ")
pred_set=set()
for r in g.query(q):
    subject = r["s"]
    typ = str(r["typ"])
    if subject in nx_namespace and "Property" in typ:
        name = subject[len(nx_namespace):]
        if name in pred_set: continue
        pred_set.add(name)
        source_file = r["source_file"]
        if source_file is None: source_file = ""
        label = r["label"] 
        if label is None: label = ""
        comment = r["comment"]    
        if comment is None: comment = ""
        myline = ""
        myline += str(subject) + "\t" 
        myline += str(name) + "\t" 
        myline += str(label)+ "\t" 
        myline += str(comment) + "\t" 
        myline += str(source_file) + "\t" 
        f_out.write(myline + "\n")
        print(myline)
f_out.close()


q = """
    PREFIX : <http://nextprot.org/rdf#> 
    PREFIX db: <http://nextprot.org/rdf/db/> 
    PREFIX source: <http://nextprot.org/rdf/source/> 
    PREFIX owl: <http://www.w3.org/2002/07/owl#> 
    PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> 
    PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#> 
    PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
    SELECT ?s ?label ?source_file  ?comment ?typ
    WHERE {
        ?s rdf:type ?typ .
        optional {
            ?s :sourceFile ?source_file .
        }
        optional {
            ?s rdfs:label ?label .
        }
        optional {
            ?s rdfs:comment ?comment .
        }
    } order by ?s
"""

f_out = open("individuals.tsv","w")
print("### Named individuals in schema")
print(" ")
pred_set=set()
for r in g.query(q):
    subject = r["s"]
    typ = str(r["typ"])
    if (subject in nx_namespace or subject in db_namespace or subject in src_namespace)  and ("NamedIndividual" in typ or "Thing" in typ):
        name = subject[len(nx_namespace):]
        if name in pred_set: continue
        pred_set.add(name)
        source_file = r["source_file"]
        if source_file is None: source_file = ""
        label = r["label"] 
        if label is None: label = ""
        comment = r["comment"]    
        if comment is None: comment = ""
        myline = ""
        myline += str(subject) + "\t" 
        myline += str(name) + "\t" 
        myline += str(label)+ "\t" 
        myline += str(comment) + "\t" 
        myline += str(source_file) + "\t" 
        f_out.write(myline + "\n")
        print(myline)
f_out.close()


print("### end")



