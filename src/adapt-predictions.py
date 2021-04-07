import sys

f_in=open('fn_predictions.tsv')
sep = '\t'
headers=f_in.readline().strip().split(sep)
errors=''
if len(headers) < 7      : errors+='ERROR: missing columns in header at first line\n'
if not headers[0] == 'AC': errors+='ERROR: column 1 should contain AC but found ' + headers[0]
if not headers[1] == 'Gene name': errors+='ERROR: column 2 should contain Gene name but found ' + headers[1]
if not headers[2] == 'GO term': errors+='ERROR: column 3 should contain GO term but found ' + headers[2]
if not headers[3] == 'GO identifier': errors+='ERROR: column 4 should contain GO identifier but found ' + headers[3]
if not headers[4] == 'ECO term': errors+='ERROR: column 5 should contain ECO term but found ' + headers[4]
if not headers[5] == 'ECO AC': errors+='ERROR: column 6 should contain ECO AC but found ' + headers[5]
if not headers[6] == 'PMID': errors+='ERROR: column 7 should contain PMID but found ' + headers[6]
if len(errors)>0 :
  print(errors)
  sys.exit()

f_out = open('fn_predictions.ok', 'w')
while True:
  line = f_in.readline()
  if line == '': break
  fields = line.strip().split(sep)
  entry_ac   = fields[0]
  cv_term_ac = fields[3]
  evidence_code_ac = fields[5]
  publication_ac = fields[6]
  publication_db = 'PubMed'
  if publication_ac == '':
    publication_ac = None
    publication_db = None
  user_orcid = '0000-0002-0819-0473'
  user_email = 'Paula.Duek@sib.swiss'
  user_label = 'neXtProt'
  user_hidden = True
  newline = ''
  newline += entry_ac + sep + cv_term_ac + sep + evidence_code_ac + sep + publication_ac + sep
  newline += publication_db + sep + user_orcid + sep + user_email + sep + user_label + sep + str(user_hidden) + '\n' 
  f_out.write(newline)

f_in.close()
f_out.close()
print('Done, output file is fn_predictions.ok')

