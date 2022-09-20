import rdflib
from rdflib import URIRef, Literal
from rdflib.namespace import Namespace
from rdflib.namespace import XSD
import sys


def getHref(label):
    words = label.split(" ")
    for w in words[1:]:
        w = w[0].lower() + w[1:]
    return "".join(words)


# input files with current schema in ttl format, current schema.html generated with pylode
ttl_file="schema.ttl"
html_file = "schema.html"

# output file
out_file = "schema-fixed.html"

# load graph from current schema.ttl file
print("### Reading and loading current graph schema", ttl_file)
g = rdflib.Graph()
g.parse(ttl_file)
print("### Graph triple count", len(g))

# collect URI with their label
q = """
    SELECT ?subj ?label WHERE {
        ?subj <http://www.w3.org/2000/01/rdf-schema#label> ?label .
    } order by ?subj
"""
href_set = set()
dico = dict()
for row in g.query(q):
    subj = str(row["subj"])
    if subj.startswith("http://nextprot.org/rdf") :
        label = str(row["label"])
        href = getHref(label)
        if href in href_set: href = href + "1"
        if href in href_set: href = href + "2"
        if href in href_set: href = href + "3"
        href_set.add(href)
        dico[subj]=href
        print(subj, label, href)            

# read schema.html, find lines that need a change and do it

f_in=open(html_file)
f_out=open(out_file,"w")
while True:
    line = f_in.readline()
    if line=="":break
    p1 = line.find("<a href=\"http://nextprot.org")
    if p1 >= 0:
        p2 = line.find(">",p1)
        print("ori", line[:p1], "|",line[p1:p2], "|", line[p2:])
        uri = line[p1+9:p2-1]
        print("uri", uri)
        href= dico.get(uri)
        if href is not None:
            newline = line[:p1] + "<a href=\"#" + href + "\"" + line[p2:]
            f_out.write(newline)
            #print("new", newline)
        else:
            f_out.write(line)
    else:
        f_out.write(line)
        
f_in.close()
f_out.close()

print("### end")

