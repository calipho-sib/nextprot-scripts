echo "started at $(date)"
#files="Y MT"
for i in high-expression inferredChildOf-a inferredChildOf-b inferredSubClassOf-a inferredSubClassOf-b low-expression medium-expression; do  
  echo "starting loading file ${i}.ttl at $(date)" 
  cmd="curl -X POST --data-binary 'uri=file:///work/ttldata/construct/${i}.ttl' http://localhost:9999/bigdata/sparql"
  echo $cmd
  eval "$cmd"
done
wait
echo "finished at $(date)"

