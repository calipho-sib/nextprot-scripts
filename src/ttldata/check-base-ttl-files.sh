ttl_dir=/work/ttldata/nobackup/export-ttl
jetty_dir=/work/jetty
expected_results=$(psql -Upostgres -dnextprot -A -t -F'=' -f /work/ttldata/entries-by-chr.sql)
for item in $expected_results ; do 
  name=$(echo $item | cut -d'=' -f1)
  file=$ttl_dir/$name.ttl
  exp_cnt=$(echo $item | cut -d'=' -f2)
  act_cnt=$(grep -c "a :Entry" $file)
  dollar_cnt=$(grep -c "\\$" $file)
  status=OK
  if [ "$act_cnt" != "$exp_cnt" ]; then status=ERROR; fi
  if [ "$dollar_cnt" != "0" ]; then status=ERROR; fi
  echo "-------------------------------------------------------------"
  echo $file - $status
  echo "-------------------------------------------------------------"
  echo "entry actual count...: $act_cnt"
  echo "entry expected count.: $exp_cnt"
  echo "dollar count.........: $dollar_cnt"
  if [ "$status" == "ERROR" ] && [ "$act_cnt" != "0" ]; then
    echo "Three last entries...:"
    grep "a :Entry" $file | tail -n3
  fi
  echo ""  
done
for item in experimentalcontext.ttl publication.ttl terminology.ttl schema.ttl; do
  file=$ttl_dir/$item
  #dollar_cnt=$(grep -c "\\$" $file)
  dollar_cnt=$(grep  "\\$" $file | grep -cv "Functional Promoter Haplotypes Decipher")
  status=OK
  if [ "$dollar_cnt" != "0" ]; then status=ERROR; fi
  echo "-------------------------------------------------------------"
  echo $file - $status
  echo "-------------------------------------------------------------"
  echo "dollar count.........: $dollar_cnt"
  if [ "$status" == "ERROR" ] ; then
    echo "Ten last lines with $:"
    grep "\\$" $file | tail
  fi
  echo ""  
done

file=$jetty_dir/logs/$(ls -1tr $jetty_dir/logs | tail -n1) 
err_cnt=$(grep -v "WARN" $file | grep -ciE "Exception|Error" ) 
status=OK
if [ "$err_cnt" != "0" ]; then status=ERROR; fi
echo "-------------------------------------------------------------"
echo $file - $status
echo "-------------------------------------------------------------"
echo "error count..........: $err_cnt"
if [ "$status" == "ERROR" ] ; then
  echo "Ten last errors:"
  grep -iE "Exception|Error" $file | tail
fi
echo ""  
echo "--------------"
echo "END"
echo "--------------"
echo ""

