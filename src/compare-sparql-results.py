import os
import sys

def feed_dic(qdic, file, num):
  f=open(file,"r")
  while True:
    line=f.readline()
    if line=="": break
    if not line.startswith("NXQ"): continue
    fields = line.split("\t")
    key = fields[0]
    cnt = fields[2]
    sta = fields[3]
    if key not in qdic: qdic[key]=dict()
    qdic[key]["cnt"+str(num)] = cnt if sta == "OK" else -1
  f.close()


print "# Usage:   python compare-sparql-result.py <similarity_rate> <old_result_file> <new_result_file>"
print "# Example: python compare-sparql-result.py 0.95 run-sparql-queries-20220304-1201.tsv run-sparql-queries-20211217-1206.tsv"

min_similarity = float(sys.argv[1])
file1 = sys.argv[2]
file2 = sys.argv[3]

print "# Comparing " + file1 + " and " + file2
print "# Minimum similarity rate (1.0 = 100%) : " + str(min_similarity)

qdic = dict()
sdic = dict()
feed_dic(qdic, file1, 1)
feed_dic(qdic, file2, 2)
keys = qdic.keys()
keys.sort()
for key in keys:
  rec = qdic[key]
  prev = -2 
  if "cnt1" in rec: prev = int(rec["cnt1"]) 
  curr = -2 
  if "cnt2" in rec: curr = int(rec["cnt2"])
  #print key + "\t" + str(prev) + "\t" + str(curr) 
  status = "???"
  if curr == -2:
    status = "NOT_RUN_THIS_TIME"
  elif curr == -1:
    status = "STILL_ERROR" if prev == -1 else "NOW_ERROR"
  elif curr == 0:
    status = "STILL_ZERO" if prev == 0 else "NOW_ZERO"
  elif prev <= 0: 
    status = "NOW_OK"
  else:
    if prev == curr: 
      status = "COUNT_IS_SAME"
    else:
      fprev = float(prev)
      fcurr = float(curr) 
      fdiff = float(abs(fcurr - fprev))
      sim = 1.0 - float(fdiff / fprev)
      status = "COUNT_SIMILAR" if sim >= min_similarity else "COUNT_DIFFERS"          
  if status not in sdic: sdic[status]=0
  sdic[status] += 1
  line = key + "\t" + str(prev) + "\t" + str(curr) + "\t" + status
  print line

print "# Summary"
keys = sdic.keys()
keys.sort()
for k in keys:
  print k + "\t" + str(sdic[k])

print("# End")
