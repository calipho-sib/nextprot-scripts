f_in=open("schema.html")
f_out=open("schema-images.html", "w")
line_no=0
insert_at=-1
insert_content=""
found_html_tag=False

while True:
  line = f_in.readline()
  if line == "": break
  line_no += 1

  if """<!DOCTYPE html>""" in line:
    found_html_tag = True

  if not found_html_tag: continue

  if """<h2>Overview</h2>""" in line:
    print("Found case 1 at line", line_no)
    line = """ <img src="nx-model-v2.png" style="max-width:100%;height:auto;"/> \n"""

  if """<div class="figure">""" in line: 
    print("Found case 2 at line", line_no)
    line = """ <div class="figure" style="display:none;"> \n"""

  if """<div class="entity class" id="Name">""" in line:
    print("Found case 3 at line", line_no)
    insert_at=5
    insert_content = """ <img src="nx-names.png" style="max-width:70%;height:auto" /> \n"""
  
  if """<div class="entity class" id="Proteoform">""" in line:
    print("Found case 4 at line", line_no)
    insert_at=5
    insert_content = """ <img src="nx-proteoform.png" style="max-width:70%;height:auto" /> \n"""
  
  f_out.write(line)
  insert_at -= 1
  if insert_at==0:
    print("Inserting line", insert_content.strip()) 
    f_out.write(insert_content)

f_in.close()
f_out.close()

