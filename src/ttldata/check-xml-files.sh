xml_dir=/work/ttldata/nobackup/export-xml
jetty_dir=/work/jetty

expected_results=$(psql -Upostgres -dnextprot -A -t -F'=' -f /work/ttldata/entries-by-chr.sql)
for item in $expected_results ; do 
  name=$(echo $item | cut -d'=' -f1)
  file=$xml_dir/$name.xml
  exp_cnt=$(echo $item | cut -d'=' -f2)
  act_cnt=$(grep -c "<entry accession=" $file)
  dollar_cnt=$(grep  "\\$" $file | grep -cv "Functional Promoter Haplotypes Decipher")
  #dollar_cnt=$(grep -c "\\$" $file)
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
    grep "<entry accession=" $file | tail -n3
  fi
  echo ""  
done

exp_cnt=$(psql -Upostgres -dnextprot -A -t -F'=' -f /work/ttldata/entry-count.sql)
file=$xml_dir/nextprot_all.xml
act_cnt=$(grep -c "<entry accession=" $file)
#dollar_cnt=$(grep -c "\\$" $file)
dollar_cnt=$(grep  "\\$" $file | grep -cv "Functional Promoter Haplotypes Decipher")
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
  grep "<entry accession=" $file | tail -n3
fi

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

