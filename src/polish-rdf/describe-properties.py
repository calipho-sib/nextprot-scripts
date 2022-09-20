import json

def labelize(str):
  label = ""
  for char in str:
    if char==":": continue
    if char.isupper(): label += " "
    label += char.lower()
  return label

def get_record():
  return {"prop": None, "has_range": False, "has_domain": False, "has_type": False, "has_label" : False}


def write_prop_definition(prop, write_label=True, write_domain=True, write_range=True, write_type=True):
  lines = list()
  lines.append(prop)
  wrote_some = False
  if write_label:
    wrote_some = True
    lines.append("    rdfs:label " + "\"" + prop_dic[prop]["rdfs:label"] + "\"^^xsd:string ;" )
  if write_type: 
    wrote_some = True
    lines.append("    rdf:type " + " " + prop_dic[prop]["rdf:type"] + " ;" )
  if write_domain:
    wrote_some = True
    domains = " ".join(prop_dic[prop]["rdfs:domain"])
    if " " in domains: domains = "[ a owl:Class ; owl:unionOf (" + domains + ") ; ]"
    lines.append("    rdfs:domain " + domains + " ;")
  if write_range:
    wrote_some = True
    ranges = " ".join(prop_dic[prop]["rdfs:range"])
    if " " in ranges: ranges = "[ a owl:Class ; owl:unionOf (" + ranges + ") ; ]"
    lines.append("    rdfs:range " + ranges + " ;") 
  if wrote_some:
    print("# added with rdfhelp data for property:", prop )
    for l in lines: print(l)
    print("    . ")
    print(" ")
  else:
    print("# nothing to add for property:", prop )
    print(" ")


def write_prop_definition_old(prop, write_label=True, write_domain=True, write_range=True, write_type=True):
  wrote_some = False
  if write_label:
    wrote_some = True
    print(prop, "rdfs:label", "\"" + prop_dic[prop]["rdfs:label"] + "\"^^xsd:string ;" )
  if write_type: 
    wrote_some = True
    print(prop, "rdf:type", prop_dic[prop]["rdf:type"] + " ;" )
  if write_domain:
    wrote_some = True
    domains = " ".join(prop_dic[prop]["rdfs:domain"])
    if " " in domains: domains = "[ a owl:Class ; owl:unionOf (" + domains + ") ; ]"
    print(prop, "rdfs:domain", domains, ";")
  if write_range:
    wrote_some = True
    ranges = " ".join(prop_dic[prop]["rdfs:range"])
    if " " in ranges: ranges = "[ a owl:Class ; owl:unionOf (" + ranges + ") ; ]"
    print(prop, "rdfs:range", ranges, ";") 
  if wrote_some:
    print("# added with rdfhelp data for property:", prop )
    print(" . ")
  else:
    print("# nothing to add for property:", prop )


global prop_dic
prop_dic = dict()
 
f_in=open('rdfhelp-20220715-0258.json')
data = json.load(f_in)
for cl in data:
  for triple in cl.get("triples"):
    prop = triple.get("predicate")
    if not prop.startswith(":"): continue
    if prop not in prop_dic: prop_dic[prop] = { "rdfs:domain": set(), "rdfs:range": set(), "appears_in_schema": False}
    prop_dic[prop].get("rdfs:domain").add(triple.get("subjectType"))
    prop_dic[prop].get("rdfs:range").add(triple.get("objectType")) 
    prop_dic[prop]["rdf:type"] = "owl:DatatypeProperty" if triple.get("literalType") else "owl:ObjectProperty" 
    prop_dic[prop]["rdfs:label"] = labelize(prop)
f_in.close()



# perform some cleaning of classes in domains,ranges, and property names
if 1==1:
  for el in prop_dic:
    for k in ["rdfs:range", "rdfs:domain"]:
      s = prop_dic[el].get(k)
      if ":Isoform" in s and ":Proteoform" in s:
        s.remove(":Proteoform")
      if ":Publication" in s and ":LargeScalePublication" in s:
        s.remove(":LargeScalePublication")
      if ":FamilyInfo" in s :
        s.remove(":FamilyInfo")
        s.add(":FamilyName")
      if ":ProteinExistence" in s :
        s.remove(":ProteinExistence")
        s.add(":ProteinExistenceLevel")
      if "BlankNodeType" in s :
        s.remove("BlankNodeType")
        
  if ":family" in prop_dic and ":familyName" not in prop_dic:
    prop_dic[":familyName"] = prop_dic[":family"]
    del prop_dic[":family"]
    


# for el in prop_dic: print(el)


print(" ")
print("# Properties already partially defined")
print(" ")

f_in=open('schema.ttl')
line_num=0
record = get_record() 
while True:
  line=f_in.readline()
  if not line: break
  line_num += 1
  data = line.rstrip()
  tokens = data.split()
  first_token = tokens[0] if len(tokens)>0 else  ""
  
  # if we're moving to a new class / property definition
  if (first_token in prop_dic and data.startswith(first_token)) or first_token == "." :
    print("### first_token", first_token)
    
    # then it is time to write missing part of definition of current record
    prop = record["prop"]
    if prop in prop_dic:
      prop_dic[prop]["appears_in_schema"] = True
      #print("would write definition", prop)
      write_prop_definition(prop,
          write_label=not record["has_label"],
          write_type=not record["has_type"],
          write_domain=not record["has_domain"],
          write_range=not record["has_range"]
        )

    # and to init new record on new known property or on end of some property
    record = get_record()
    print("### init rec")
    if first_token in prop_dic: record["prop"] = first_token

  has_prop = True if record["prop"] is not None else False
  if "rdfs:label" in data and has_prop: record["has_label"] = True
  if "rdfs:domain" in data and has_prop: record["has_domain"] = True
  if "rdfs:range" in data and has_prop: record["has_range"] = True
  if "rdf:type" in data and has_prop: record["has_type"] = True
  if "rdf:Property" in data and has_prop: record["has_type"] = True
  if "owl:DatatypeProperty" in data and has_prop: record["has_type"] = True
  if "owl:ObjectProperty" in data and has_prop: record["has_type"] = True
  if "owl:TransitiveProperty" in data and has_prop: record["has_type"] = True

  print("###",
        "prop:",  record["prop"],
        ", label:", record["has_label"],
        ", type:",  record["has_type"],
        ", domain:", record["has_domain"],
        ", range:", record["has_range"],
        ", token:",first_token,
        ", data:", data[:50])

f_in.close()

print(" ")
print("# Properties not defined at all")
print(" ")
for prop in prop_dic:
  if not prop.startswith(":"): continue 
  rec = prop_dic[prop]
  if rec["appears_in_schema"] == False:
    write_prop_definition(prop)

print(" ")
print("### ---------------")
print("### lines in schema.ttl", line_num)
print("### end")



