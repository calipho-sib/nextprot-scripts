import json

print("Reading original rdfhelp file")
f_in=open('rdfhelp-20220922-1207.json')
new_data = list()
data = json.load(f_in)
f_in.close()

print("Reading named individuals to be removed")
to_del=set()
f_in=open('nextprot-rdf-classes - nextprot-named-individuals.tsv')
while True:
  line=f_in.readline()
  if line=="": break
  fields = line.split("\t")
  if not line.startswith("http"): continue
  st = fields[2]
  if st.lower() != "private": continue
  iri = fields[0][24:]
  if iri.startswith("db/"):
    iri = "db:" + iri[3:]
  elif iri.startswith("source/"):
    iri = "source:" + iri[7:]
  to_del.add(iri)
  print("Adding element to be deleted", iri)
f_in.close()

for cl in data:
  tn = cl.get("typeName")
  pc = cl.get("parents")
  ptc = cl.get("parentTriples")
  
  # do not include Classes having no parent
  if len(ptc)==0:
    print("Skipping class without parent", tn) 
    continue

  # remove triples with owl classes in object type
  new_triples = list()
  for triple in cl.get("triples"):
    ot = triple.get("objectType")
    if "owl:" in ot:
      st = triple.get("subjectType")
      pred = triple.get("predicate")
      print("Removing triple type", st, pred, ot)
      continue
    new_triples.append(triple)
  # fix values (seems to be unnecessary)
  new_values = list()
  for v in cl.get("values"):
    if v in to_del:
      print("Removing value", v , "from class", tn) 
      continue
    new_values.append(v)
  new_data.append(cl)
 
print("Writing rdfhelp-clean.json")
f_out=open('rdfhelp-clean.json', 'w')
json.dump(new_data,f_out)
f_out.close()

